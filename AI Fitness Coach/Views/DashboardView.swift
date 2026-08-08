import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \MealEntry.date, order: .reverse) private var meals: [MealEntry]
    @Query(sort: \DailyMetric.date) private var metrics: [DailyMetric]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let profile = profiles.first {
                    let targets = NutritionCalculator.targets(for: profile)
                    let todayMeals = meals.filter { Calendar.current.isDateInToday($0.date) }
                    let calories = todayMeals.reduce(0) { $0 + $1.calories }
                    let protein = todayMeals.reduce(0) { $0 + $1.protein }
                    let fat = todayMeals.reduce(0) { $0 + $1.fat }
                    let carbs = todayMeals.reduce(0) { $0 + $1.carbs }

                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        MetricCard(title: "Калории", value: "\(Int(calories))", target: "\(Int(targets.calories)) ккал", progress: NutritionCalculator.progress(current: calories, target: targets.calories), tint: .greenAccent)
                        MetricCard(title: "Белок", value: "\(Int(protein))", target: "\(Int(targets.protein)) г", progress: NutritionCalculator.progress(current: protein, target: targets.protein), tint: .purpleAccent)
                        MetricCard(title: "Жиры", value: "\(Int(fat))", target: "\(Int(targets.fat)) г", progress: NutritionCalculator.progress(current: fat, target: targets.fat), tint: .purpleAccent)
                        MetricCard(title: "Углеводы", value: "\(Int(carbs))", target: "\(Int(targets.carbs)) г", progress: NutritionCalculator.progress(current: carbs, target: targets.carbs), tint: .yellowAccent)
                    }

                    weightTrend(profile: profile)
                    coachRecommendation(profile: profile, targets: targets, calories: calories, protein: protein)
                    dayPlan(profile: profile, targets: targets, calories: calories, protein: protein)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 110)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now, format: .dateTime.day().month().year())
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Локальный AI Coach")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Label("AI", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
                )
        }
    }

    private func weightTrend(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ТРЕНД ВЕСА")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            GlassPanel {
                Chart(weightSeries(profile: profile)) { point in
                    AreaMark(
                        x: .value("Дата", point.date),
                        y: .value("Вес", point.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellowAccent.opacity(0.32), Color.greenAccent.opacity(0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Дата", point.date),
                        y: .value("Вес", point.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [Color.orange, Color.yellowAccent, Color.greenAccent], startPoint: .leading, endPoint: .trailing)
                    )
                    .lineStyle(.init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Дата", point.date),
                        y: .value("Вес", point.weight)
                    )
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolSize(34)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 140)

                Text("Цель: \(String(format: "%.1f", profile.currentWeightKg)) -> \(String(format: "%.1f", profile.targetWeightKg)) кг")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private func coachRecommendation(profile: UserProfile, targets: NutritionTargets, calories: Double, protein: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("РЕКОМЕНДАЦИИ AI")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            GlassPanel {
                HStack(spacing: 14) {
                    Image(systemName: "face.smiling.inverse")
                        .font(.system(size: 42))
                        .foregroundStyle(Color.purpleAccent)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(.purple.opacity(0.16)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendationText(targets: targets, calories: calories, protein: protein))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                        Text("План адаптируется локально каждый день.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()
                }
            }
        }
    }

    private func dayPlan(profile: UserProfile, targets: NutritionTargets, calories: Double, protein: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ПЛАН НА ДЕНЬ")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))

            VStack(spacing: 10) {
                PlanRow(icon: "fork.knife", title: "Питание", value: "\(Int(calories)) / \(Int(targets.calories)) ккал", progress: NutritionCalculator.progress(current: calories, target: targets.calories), tint: .greenAccent)
                PlanRow(icon: "figure.strengthtraining.traditional", title: "Тренировка", value: "\(profile.trainingDaysPerWeek) / нед", progress: 0.65, tint: .purpleAccent)
                PlanRow(icon: "figure.walk", title: "Активность", value: "Цель 10 000 шагов", progress: 0.72, tint: .yellowAccent)
                PlanRow(icon: "drop.fill", title: "Вода", value: "\(String(format: "%.1f", targets.waterLiters)) л", progress: 0.58, tint: .blueAccent)
            }
        }
    }

    private func weightSeries(profile: UserProfile) -> [WeightPoint] {
        let saved = metrics.map { WeightPoint(date: $0.date, weight: $0.weightKg) }
        guard saved.count < 2 else { return saved }

        return (0..<5).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .day, value: index - 4, to: .now) else { return nil }
            let drift = Double(index) * ((profile.targetWeightKg - profile.currentWeightKg) / 80)
            return WeightPoint(date: date, weight: profile.currentWeightKg + drift)
        }
    }

    private func recommendationText(targets: NutritionTargets, calories: Double, protein: Double) -> String {
        if protein < targets.protein * 0.75 {
            return "До белка осталось \(Int(targets.protein - protein)) г. Лучше добрать ужином, без лишних углеводов."
        }

        if calories > targets.calories * 1.1 {
            return "Калории выше плана. Не голодаем: завтра мягко добавим шаги и сделаем рацион плотнее по белку."
        }

        return "Темп хороший. Держим калории, воду и сон; резких корректировок сегодня не нужно."
    }
}

private struct WeightPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

private struct PlanRow: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        GlassPanel {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28)

                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.68))
            }

            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * min(progress, 1))
                    }
            }
            .frame(height: 5)
        }
    }
}
