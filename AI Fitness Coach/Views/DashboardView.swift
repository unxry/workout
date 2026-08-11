import Charts
import SwiftUI
import UIKit

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: LocalDataStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showReminders = false
    @State private var activePlanDetail: PlanDetail?
    @State private var day = DayContext()
    @State private var lastRefresh = Date.now
    @State private var healthStatus = "Данные Apple Health еще не синхронизированы."
    @State private var hourlySteps: [StepHourBucket] = []
    @State private var isSyncingHealth = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                SectionHeader(title: "СВОДКА ЗА ДЕНЬ")
                summaryGrid
                weightTrendSection
                localInsightSection
                dayPlanSection
                remindersSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 144)
        }
        .sheet(item: $activePlanDetail) { detail in
            PlanDetailSheet(
                detail: detail,
                totals: totals,
                targets: targets,
                meals: todayMeals,
                metric: todayMetric,
                waterEntries: todayWaterEntries,
                hourlySteps: hourlySteps,
                healthStatus: healthStatus,
                currentWeight: currentWeight,
                targetWeight: targetWeight
            ) {
                Task { await syncHealthMetrics(requestAuthorization: true) }
            }
        }
        .sheet(isPresented: $showReminders) {
            SimpleInfoSheet(title: "Напоминания", rows: reminders.map { "\($0.title) - \($0.subtitle) - \($0.time)" })
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                refreshDay()
                Task { await syncHealthMetrics(requestAuthorization: false) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshDay()
            Task { await syncHealthMetrics(requestAuthorization: false) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
            refreshDay()
            Task { await syncHealthMetrics(requestAuthorization: false) }
        }
        .task {
            await syncHealthMetrics(requestAuthorization: false)
        }
    }

    private var profile: UserProfile? { store.profile }
    private var targets: NutritionTargets {
        if let profile { return NutritionCalculator.targets(for: profile) }
        return NutritionTargets(bmr: 1650, tdee: 2600, calories: 2900, protein: 125, fat: 75, carbs: 400, waterLiters: 2.5, weeklyWeightDelta: -0.4, goalDate: .now)
    }

    private var todayMeals: [MealEntry] {
        store.meals.filter { day.contains($0.date) }
    }

    private var todayMetric: DailyMetric? {
        store.metrics.last { day.contains($0.date) }
    }

    private var todayWaterEntries: [WaterEntry] {
        store.waterEntries.filter { day.contains($0.date) }
    }

    private var totals: MacroTotals {
        return MacroTotals(
            calories: todayMeals.reduce(0) { $0 + $1.calories },
            protein: todayMeals.reduce(0) { $0 + $1.protein },
            fat: todayMeals.reduce(0) { $0 + $1.fat },
            carbs: todayMeals.reduce(0) { $0 + $1.carbs }
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(day.formattedDate)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            HStack(spacing: 7) {
                Text("Обновлено \(timeString(lastRefresh))")
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(AppColors.secondaryText)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [.init(.flexible(), spacing: 14), .init(.flexible(), spacing: 14)], spacing: 14) {
            MetricCard(title: "Калории", value: "\(Int(totals.calories))", target: "\(Int(targets.calories)) ккал", progress: totals.calories / targets.calories, tint: AppColors.green)
            MetricCard(title: "Белок", value: String(format: "%.1f", totals.protein), target: "\(Int(targets.protein)) г", progress: totals.protein / targets.protein, tint: AppColors.purple)
            MetricCard(title: "Жиры", value: String(format: "%.1f", totals.fat), target: "\(Int(targets.fat)) г", progress: totals.fat / targets.fat, tint: AppColors.purple)
            MetricCard(title: "Углеводы", value: String(format: "%.1f", totals.carbs), target: "\(Int(targets.carbs)) г", progress: totals.carbs / targets.carbs, tint: AppColors.yellow)
        }
    }

    private var weightTrendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "ТРЕНД ВЕСА")
            PremiumCard(padding: 13, radius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    WeightTrendVisual(points: weightPoints)
                        .frame(height: 126)
                    Text("Цель: \(String(format: "%.1f", currentWeight)) → \(String(format: "%.1f", targetWeight)) кг")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    private var localInsightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "СОВЕТ НА СЕГОДНЯ")
            PremiumCard(padding: 18, radius: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        insightIcon(size: 72)
                        insightText
                            .layoutPriority(1)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            insightIcon(size: 68)
                            insightText
                                .layoutPriority(1)
                        }
                    }
                }
            }
        }
    }

    private var insight: LocalCoachInsight {
        LocalCoachEngine.insight(totals: totals, targets: targets, metrics: store.metrics, weightHistory: store.metrics, now: day.date, calendar: day.calendar)
    }

    private var insightTint: Color {
        switch insight.tintName {
        case "blue": AppColors.blue
        case "yellow": AppColors.yellow
        case "green": AppColors.green
        default: AppColors.purple
        }
    }

    private var insightText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(insight.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(insightTint)
                .fixedSize(horizontal: false, vertical: true)
            Text(insight.message)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func insightIcon(size: CGFloat) -> some View {
        IconBadge(systemName: "lightbulb.fill", tint: insightTint, size: size)
    }

    private var dayPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ПЛАН НА ДЕНЬ", actionTitle: "См. все") { activePlanDetail = .all }
            VStack(spacing: 6) {
                DashboardPlanRow(icon: "fork.knife", title: "Питание", value: "\(Int(totals.calories)) / \(Int(targets.calories)) ккал", percent: Int((totals.calories / targets.calories * 100).rounded()), progress: totals.calories / targets.calories, tint: AppColors.green) {
                    activePlanDetail = .nutrition
                }
                DashboardPlanRow(icon: "figure.walk", title: "Активность", value: "\(todayMetric?.steps ?? 0) / 10 000 шагов", percent: Int((Double(todayMetric?.steps ?? 0) / 10_000 * 100).rounded()), progress: Double(todayMetric?.steps ?? 0) / 10_000, tint: AppColors.yellow) {
                    activePlanDetail = .activity
                }
                DashboardPlanRow(icon: "drop.fill", title: "Вода", value: "\(String(format: "%.1f", todayMetric?.waterLiters ?? 0)) / \(String(format: "%.1f", targets.waterLiters)) л", percent: Int((((todayMetric?.waterLiters ?? 0) / targets.waterLiters) * 100).rounded()), progress: (todayMetric?.waterLiters ?? 0) / targets.waterLiters, tint: AppColors.blue) {
                    activePlanDetail = .water
                }
                DashboardPlanRow(icon: "scalemass", title: "Вес", value: "\(String(format: "%.1f", currentWeight)) / \(String(format: "%.1f", targetWeight)) кг", percent: Int(NutritionCalculator.progress(current: currentWeight, target: targetWeight) * 100), progress: NutritionCalculator.progress(current: currentWeight, target: targetWeight), tint: AppColors.purple) {
                    activePlanDetail = .weight
                }
            }
        }
    }

    private var remindersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "НАПОМИНАНИЯ", actionTitle: "См. все") { showReminders = true }
            VStack(spacing: 6) {
                ForEach(reminders) { reminder in
                    ReminderRow(reminder: reminder)
                }
            }
        }
    }

    private var reminders: [ReminderItem] {
        [
            ReminderItem(icon: "bell", tint: AppColors.blue, title: "Выпей воду", subtitle: "Каждые 2 часа", time: "01:00"),
            ReminderItem(icon: "scalemass", tint: AppColors.green, title: "Взвешивание", subtitle: "Утром после пробуждения", time: "08:00"),
            ReminderItem(icon: "capsule.fill", tint: AppColors.orange, title: "Добавка", subtitle: "Омега-3 • После еды", time: "13:00")
        ]
    }

    private var currentWeight: Double { profile?.currentWeightKg ?? 62.0 }
    private var targetWeight: Double { profile?.targetWeightKg ?? 67.0 }

    private var weightPoints: [WeightVisualPoint] {
        if store.metrics.count >= 3 {
            let recent = store.metrics.suffix(3)
            return recent.map { metric in
                WeightVisualPoint(label: shortDate(metric.date), value: metric.weightKg)
            }
        }
        if let profile {
            return [WeightVisualPoint(label: shortDate(.now), value: profile.currentWeightKg)]
        }
        return []
    }

    private func refreshDay() {
        day = DayContext()
        lastRefresh = .now
    }

    private func syncHealthMetrics(requestAuthorization: Bool) async {
        guard !isSyncingHealth else { return }
        guard appState.healthKit.isAvailable else {
            healthStatus = "Apple Health недоступен на этом устройстве."
            return
        }

        isSyncingHealth = true
        defer { isSyncingHealth = false }

        do {
            if requestAuthorization {
                try await appState.healthKit.requestAuthorization()
            }
            let snapshot = try await appState.healthKit.todayActivitySnapshot(calendar: day.calendar)
            let buckets = try await appState.healthKit.hourlySteps(for: day)
            store.updateActivity(steps: snapshot.steps, activeEnergyKcal: snapshot.activeEnergyKcal, on: .now, calendar: day.calendar)
            hourlySteps = buckets
            healthStatus = requestAuthorization ? "Apple Health подключен. Обновлено \(timeString(.now))." : "Синхронизировано с Apple Health: \(timeString(.now))."
            lastRefresh = .now
        } catch {
            healthStatus = requestAuthorization ? "Не удалось подключить Apple Health: \(error.localizedDescription)" : "Открой детали активности и нажми «Считать из Здоровья»."
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: date)
    }
}

struct MacroTotals {
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
}

private struct WeightVisualPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

private struct WeightTrendVisual: View {
    let points: [WeightVisualPoint]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let chartRect = CGRect(x: 12, y: 18, width: max(1, size.width - 24), height: size.height - 48)
            let coordinates = makeCoordinates(in: chartRect)
            ZStack {
                if coordinates.count >= 2 {
                    areaPath(points: coordinates, bottom: chartRect.maxY)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.green.opacity(0.34), AppColors.yellow.opacity(0.20), AppColors.orange.opacity(0.10), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(points: coordinates)
                        .stroke(
                            LinearGradient(colors: [AppColors.orange, AppColors.yellow, AppColors.green], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: AppColors.green.opacity(0.35), radius: 4)

                    ForEach(Array(coordinates.enumerated()), id: \.offset) { index, point in
                        Circle()
                            .fill(AppColors.panelDeep)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(.white.opacity(0.78), lineWidth: 1.5))
                            .position(point)
                        Text(String(format: "%.1f", points[index].value))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .position(x: point.x, y: max(8, point.y - 17))
                        Text(points[index].label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AppColors.mutedText)
                            .position(x: point.x, y: chartRect.maxY + 22)
                    }
                } else {
                    Text("История веса появится после нескольких записей.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 18)
                }
            }
        }
    }

    private func makeCoordinates(in rect: CGRect) -> [CGPoint] {
        guard let minValue = points.map(\.value).min(), let maxValue = points.map(\.value).max(), points.count > 1 else { return [] }
        let span = max(maxValue - minValue, 0.1)
        return points.enumerated().map { index, point in
            let x = rect.minX + (CGFloat(index) / CGFloat(points.count - 1)) * rect.width
            let normalized = CGFloat((point.value - minValue) / span)
            let y = rect.maxY - normalized * rect.height * 0.72 - rect.height * 0.10
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            path.move(to: points[0])
            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let controlX = (previous.x + current.x) / 2
                path.addCurve(to: current, control1: CGPoint(x: controlX, y: previous.y), control2: CGPoint(x: controlX, y: current.y))
            }
        }
    }

    private func areaPath(points: [CGPoint], bottom: CGFloat) -> Path {
        var path = linePath(points: points)
        if let last = points.last, let first = points.first {
            path.addLine(to: CGPoint(x: last.x, y: bottom))
            path.addLine(to: CGPoint(x: first.x, y: bottom))
            path.closeSubpath()
        }
        return path
    }
}

private enum PlanDetail: String, Identifiable {
    case all
    case nutrition
    case activity
    case water
    case weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "План на день"
        case .nutrition: "Питание"
        case .activity: "Активность"
        case .water: "Вода"
        case .weight: "Вес"
        }
    }
}

private struct PlanDetailSheet: View {
    let detail: PlanDetail
    let totals: MacroTotals
    let targets: NutritionTargets
    let meals: [MealEntry]
    let metric: DailyMetric?
    let waterEntries: [WaterEntry]
    let hourlySteps: [StepHourBucket]
    let healthStatus: String
    let currentWeight: Double
    let targetWeight: Double
    let onSyncHealth: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PremiumBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(detail.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(Color.white.opacity(0.10)))
                        }
                    }

                    if detail == .all || detail == .nutrition { nutritionBlock }
                    if detail == .all || detail == .activity { activityBlock }
                    if detail == .all || detail == .water { waterBlock }
                    if detail == .all || detail == .weight { weightBlock }
                }
                .padding(22)
                .padding(.bottom, 28)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var nutritionBlock: some View {
        detailSection(title: "Питание", icon: "fork.knife", tint: AppColors.green) {
            detailLine("Калории", "\(Int(totals.calories)) / \(Int(targets.calories)) ккал")
            detailLine("Белок", "\(Int(totals.protein)) / \(Int(targets.protein)) г")
            detailLine("Жиры", "\(Int(totals.fat)) / \(Int(targets.fat)) г")
            detailLine("Углеводы", "\(Int(totals.carbs)) / \(Int(targets.carbs)) г")
            Divider().overlay(Color.white.opacity(0.10))
            if meals.isEmpty {
                muted("Сегодня приемов пищи еще нет.")
            } else {
                ForEach(meals) { meal in
                    detailLine(timeString(meal.date), "\(meal.title) • \(Int(meal.calories)) ккал")
                }
            }
        }
    }

    private var activityBlock: some View {
        detailSection(title: "Активность", icon: "figure.walk", tint: AppColors.yellow) {
            detailLine("Шаги", "\(metric?.steps ?? 0) / 10 000")
            detailLine("Активная энергия", "\(Int((metric?.activeEnergyKcal ?? 0).rounded())) ккал")
            muted(healthStatus)
            Button {
                onSyncHealth()
            } label: {
                Label("Считать из Здоровья", systemImage: "heart.text.square")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(AppColors.purple.opacity(0.24)))
                    .overlay(Capsule().stroke(AppColors.purple.opacity(0.65), lineWidth: 1))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Divider().overlay(Color.white.opacity(0.10))
            if hourlySteps.isEmpty {
                muted("Почасовая история шагов появится после синхронизации Apple Health.")
            } else {
                ForEach(hourlySteps) { bucket in
                    detailLine(hourRange(bucket), "\(bucket.steps) шагов")
                }
            }
        }
    }

    private var waterBlock: some View {
        detailSection(title: "Вода", icon: "drop.fill", tint: AppColors.blue) {
            detailLine("Выпито", "\(String(format: "%.1f", metric?.waterLiters ?? 0)) / \(String(format: "%.1f", targets.waterLiters)) л")
            Divider().overlay(Color.white.opacity(0.10))
            if waterEntries.isEmpty {
                muted("Сегодня воду еще не добавляли.")
            } else {
                ForEach(waterEntries) { entry in
                    detailLine(timeString(entry.date), "+\(String(format: "%.2f", entry.liters)) л")
                }
            }
        }
    }

    private var weightBlock: some View {
        detailSection(title: "Вес", icon: "scalemass", tint: AppColors.purple) {
            detailLine("Текущий вес", "\(String(format: "%.1f", currentWeight)) кг")
            detailLine("Цель", "\(String(format: "%.1f", targetWeight)) кг")
            detailLine("Прогресс", "\(Int(NutritionCalculator.progress(current: currentWeight, target: targetWeight) * 100))%")
            if let metric {
                detailLine("Последняя запись", "\(timeString(metric.date)) • \(String(format: "%.1f", metric.weightKg)) кг")
            }
        }
    }

    private func detailSection<Content: View>(title: String, icon: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        PremiumCard(padding: 16, radius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                        .frame(width: 24)
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                content()
            }
        }
    }

    private func detailLine(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 10)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.90))
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func muted(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func hourRange(_ bucket: StepHourBucket) -> String {
        "\(timeString(bucket.start))-\(timeString(bucket.end))"
    }
}

private struct DashboardPlanRow: View {
    let icon: String
    let title: String
    let value: String
    let percent: Int
    let progress: Double
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            PremiumCard(padding: 12, radius: 14) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 26)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 106, alignment: .leading)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(value)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        GradientProgressBar(progress: progress, tint: tint, height: 4)
                    }
                    Spacer(minLength: 8)
                    Text("\(percent)%")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.88))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.mutedText)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ReminderItem: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let time: String
}

private struct ReminderRow: View {
    let reminder: ReminderItem

    var body: some View {
        PremiumCard(padding: 12, radius: 14) {
            HStack(spacing: 14) {
                Image(systemName: reminder.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(reminder.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(reminder.subtitle)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.secondaryText)
                }
                Spacer()
                Text(reminder.time)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }
}

struct SimpleInfoSheet: View {
    let title: String
    let rows: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PremiumBackground()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.white.opacity(0.10)))
                    }
                }
                ForEach(rows, id: \.self) { row in
                    PremiumCard(padding: 14, radius: 16) {
                        Text(row)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.86))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer()
            }
            .padding(22)
        }
    }
}
