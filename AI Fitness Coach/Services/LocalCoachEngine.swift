import Foundation

struct LocalCoachInsight: Equatable {
    var title: String
    var message: String
    var tintName: String
}

enum LocalCoachEngine {
    static func insight(
        totals: MacroTotals,
        targets: NutritionTargets,
        metrics: [DailyMetric],
        weightHistory: [DailyMetric],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> LocalCoachInsight {
        let hour = calendar.component(.hour, from: now)
        let todayMetric = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: now) })
        let calorieProgress = targets.calories > 0 ? totals.calories / targets.calories : 0
        let proteinProgress = targets.protein > 0 ? totals.protein / targets.protein : 0

        if hour < 11, totals.calories <= 1 {
            return LocalCoachInsight(
                title: "План дня",
                message: "Сегодня цель - \(Int(targets.calories)) ккал и не менее \(Int(targets.protein)) г белка. Шаги и вода обновятся из Apple Health и дневника.",
                tintName: "green"
            )
        }

        let proteinLeft = max(targets.protein - totals.protein, 0)
        if hour >= 12, hour < 18, proteinProgress < 0.45 {
            return LocalCoachInsight(
                title: "Белок",
                message: "К \(String(format: "%02d:00", hour)) набрано \(Int(totals.protein.rounded())) из \(Int(targets.protein.rounded())) г белка. В следующий прием пищи лучше добавить белковый продукт.",
                tintName: "purple"
            )
        }

        if hour >= 18, proteinLeft >= 25 {
            let caloriesLeft = max(targets.calories - totals.calories, 0)
            return LocalCoachInsight(
                title: "Ужин",
                message: "По калориям остается около \(Int(caloriesLeft.rounded())) ккал, а белка - \(Int(proteinLeft.rounded())) г. Лучше сделать ужин с упором на белок.",
                tintName: "purple"
            )
        }

        if let metric = todayMetric {
            let waterLeft = max(targets.waterLiters - metric.waterLiters, 0)
            if hour >= 14, waterLeft >= 0.7 {
                return LocalCoachInsight(
                    title: "Вода",
                    message: "Сегодня выпито \(String(format: "%.1f", metric.waterLiters)) из \(String(format: "%.1f", targets.waterLiters)) л воды.",
                    tintName: "blue"
                )
            }

            let stepsLeft = max(10_000 - metric.steps, 0)
            if hour >= 16, stepsLeft >= 1_500 {
                return LocalCoachInsight(
                    title: "Активность",
                    message: "До цели активности осталось \(stepsLeft) шагов. Это данные Apple Health за сегодня.",
                    tintName: "yellow"
                )
            }
        }

        if let trend = sevenDayWeightTrend(weightHistory, calendar: calendar) {
            if trend < -0.04 {
                return LocalCoachInsight(title: "Тренд веса", message: "Средний вес за 7 дней снижается примерно на \(String(format: "%.2f", abs(trend * 7))) кг в неделю. Не ускоряй план без необходимости.", tintName: "green")
            }
            if abs(trend) <= 0.02, weightHistory.count >= 7 {
                return LocalCoachInsight(title: "Тренд веса", message: "Средний вес почти не меняется. Сначала проверь регулярность учета еды и шагов за неделю.", tintName: "yellow")
            }
        }

        let caloriesLeft = max(targets.calories - totals.calories, 0)
        if calorieProgress >= 0.92, calorieProgress <= 1.08, proteinProgress >= 0.90 {
            return LocalCoachInsight(
                title: "План выполнен",
                message: "Сегодня план идет хорошо: \(Int((calorieProgress * 100).rounded()))% калорий и \(Int((proteinProgress * 100).rounded()))% белка.",
                tintName: "green"
            )
        }

        if caloriesLeft > 0 {
            return LocalCoachInsight(
                title: "Питание",
                message: "До дневной цели осталось \(Int(caloriesLeft.rounded())) ккал. Держи фокус на обычной еде и белке.",
                tintName: "green"
            )
        }

        return LocalCoachInsight(title: "План", message: "Сегодня калорий выше плана. Просто вернись к обычному плану завтра, без голодания и наказаний тренировкой.", tintName: "purple")
    }

    private static func sevenDayWeightTrend(_ metrics: [DailyMetric], calendar: Calendar) -> Double? {
        let recent = metrics
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
            .suffix(7)
        guard let first = recent.first, let last = recent.last, first.id != last.id else { return nil }
        let days = max(calendar.dateComponents([.day], from: first.date, to: last.date).day ?? 1, 1)
        return (last.weightKg - first.weightKg) / Double(days)
    }
}
