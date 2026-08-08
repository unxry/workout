import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \DailyMetric.date) private var metrics: [DailyMetric]

    @State private var showReminders = false
    @State private var showPlan = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                SectionHeader(title: "СВОДКА ЗА ДЕНЬ")
                summaryGrid
                weightTrendSection
                aiRecommendation
                dayPlanSection
                remindersSection
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 118)
        }
        .sheet(isPresented: $showPlan) {
            SimpleInfoSheet(title: "План на день", rows: [
                "Питание: держим цель по калориям и белку.",
                "Тренировка: верх тела, 45-60 минут.",
                "Активность: 10 000 шагов.",
                "Вода: 2.5 л в течение дня."
            ])
        }
        .sheet(isPresented: $showReminders) {
            SimpleInfoSheet(title: "Напоминания", rows: reminders.map { "\($0.title) - \($0.subtitle) - \($0.time)" })
        }
    }

    private var profile: UserProfile? { profiles.first }
    private var targets: NutritionTargets {
        if let profile { return NutritionCalculator.targets(for: profile) }
        return NutritionTargets(bmr: 1650, tdee: 2600, calories: 2900, protein: 125, fat: 75, carbs: 400, waterLiters: 2.5, weeklyWeightDelta: -0.4, goalDate: .now)
    }

    private var todayMeals: [MealEntry] {
        meals.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var totals: MacroTotals {
        guard !todayMeals.isEmpty else {
            return MacroTotals(calories: 3250, protein: 148.5, fat: 126.9, carbs: 356)
        }
        return MacroTotals(
            calories: todayMeals.reduce(0) { $0 + $1.calories },
            protein: todayMeals.reduce(0) { $0 + $1.protein },
            fat: todayMeals.reduce(0) { $0 + $1.fat },
            carbs: todayMeals.reduce(0) { $0 + $1.carbs }
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("05.08.2026")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                HStack(spacing: 7) {
                    Text("Обновлено 23:58")
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            AIHelperButton(title: "ИИ-помощник") {
                appState.selectedTab = .coach
            }
            .padding(.top, 4)
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
            PremiumCard(padding: 14, radius: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    WeightTrendVisual(points: weightPoints)
                        .frame(height: 150)
                    Text("Цель: \(String(format: "%.1f", currentWeight)) → \(String(format: "%.1f", targetWeight)) кг")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(AppColors.secondaryText)
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    private var aiRecommendation: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "РЕКОМЕНДАЦИИ ИИ")
            PremiumCard(padding: 18, radius: 20) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        AIAvatar(size: 78)
                        aiRecommendationText
                            .layoutPriority(1)
                        aiAskButton
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 14) {
                            AIAvatar(size: 72)
                            aiRecommendationText
                                .layoutPriority(1)
                        }
                        aiAskButton
                            .frame(maxWidth: 210, alignment: .leading)
                    }
                }
            }
        }
    }

    private var aiRecommendationText: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Сегодня ты на \(Int((totals.calories / targets.calories * 100).rounded()))% по калориям.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
            Text(totals.calories > targets.calories ? "Отличный результат." : "Держим темп спокойно.")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.green)
                .fixedSize(horizontal: false, vertical: true)
            Text("Хочешь подсказку по питанию или тренировке?")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var aiAskButton: some View {
        Button {
            Haptics.tap()
            appState.openCoach(with: "Дай подсказку по питанию или тренировке на сегодня.")
        } label: {
            Text("Спросить ИИ")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(height: 44)
                .padding(.horizontal, 22)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.045))
                        .overlay(Capsule().stroke(AppColors.purple, lineWidth: 1.8))
                        .shadow(color: AppColors.purple.opacity(0.30), radius: 9)
                )
                .fixedSize(horizontal: true, vertical: false)
        }
        .buttonStyle(.plain)
    }

    private var dayPlanSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "ПЛАН НА ДЕНЬ", actionTitle: "См. все") { showPlan = true }
            VStack(spacing: 6) {
                DashboardPlanRow(icon: "fork.knife", title: "Питание", value: "\(Int(totals.calories)) / \(Int(targets.calories)) ккал", percent: Int((totals.calories / targets.calories * 100).rounded()), progress: totals.calories / targets.calories, tint: AppColors.green)
                DashboardPlanRow(icon: "dumbbell", title: "Тренировка", value: "450 / 400 ккал", percent: 112, progress: 1.12, tint: AppColors.purple)
                DashboardPlanRow(icon: "figure.walk", title: "Активность", value: "8 250 / 10 000 шагов", percent: 82, progress: 0.82, tint: AppColors.yellow)
                DashboardPlanRow(icon: "drop.fill", title: "Вода", value: "1.8 / \(String(format: "%.1f", targets.waterLiters)) л", percent: 72, progress: 0.72, tint: AppColors.blue)
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
            ReminderItem(icon: "dumbbell", tint: AppColors.orange, title: "Тренировка", subtitle: "Верх тела • 19:00", time: "19:00"),
            ReminderItem(icon: "capsule.fill", tint: AppColors.orange, title: "Добавка", subtitle: "Омега-3 • После еды", time: "13:00")
        ]
    }

    private var currentWeight: Double { profile?.currentWeightKg ?? 62.0 }
    private var targetWeight: Double { profile?.targetWeightKg ?? 67.0 }

    private var weightPoints: [WeightVisualPoint] {
        if metrics.count >= 3 {
            let recent = metrics.suffix(3)
            return recent.enumerated().map { index, metric in
                WeightVisualPoint(label: ["01.08", "03.08", "05.08"][min(index, 2)], value: metric.weightKg)
            }
        }
        return [
            WeightVisualPoint(label: "01.08", value: 62.0),
            WeightVisualPoint(label: "03.08", value: 63.2),
            WeightVisualPoint(label: "05.08", value: 63.0)
        ]
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
            let chartRect = CGRect(x: 12, y: 18, width: size.width - 24, height: size.height - 48)
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

private struct AIAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.purple.opacity(0.16))
                .overlay(Circle().stroke(AppColors.purple, lineWidth: 3))
                .shadow(color: AppColors.purple.opacity(0.35), radius: 14)
            Image(systemName: "robot")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [AppColors.purple, AppColors.blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
        .frame(width: size, height: size)
    }
}

private struct DashboardPlanRow: View {
    let icon: String
    let title: String
    let value: String
    let percent: Int
    let progress: Double
    let tint: Color

    var body: some View {
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
                    GradientProgressBar(progress: progress, tint: tint, height: 4)
                }
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
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
