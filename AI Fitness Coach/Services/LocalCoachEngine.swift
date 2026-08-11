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
        let proteinLeft = max(targets.protein - totals.protein, 0)
        if proteinLeft >= 20 {
            return LocalCoachInsight(
                title: "Белок",
                message: "До цели по белку осталось \(Int(proteinLeft.rounded())) г. Подойдут творог, курица, яйца или рыба.",
                tintName: "purple"
            )
        }

        if let metric = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: now) }) {
            let waterLeft = max(targets.waterLiters - metric.waterLiters, 0)
            if waterLeft >= 0.5 {
                return LocalCoachInsight(
                    title: "Вода",
                    message: "Сегодня выпито \(String(format: "%.1f", metric.waterLiters)) из \(String(format: "%.1f", targets.waterLiters)) л воды.",
                    tintName: "blue"
                )
            }

            let stepsLeft = max(10_000 - metric.steps, 0)
            if stepsLeft >= 1_500 {
                return LocalCoachInsight(
                    title: "Активность",
                    message: "До дневной цели осталось \(stepsLeft) шагов. Можно добрать прогулкой 15-20 минут.",
                    tintName: "yellow"
                )
            }
        }

        if let trend = sevenDayWeightTrend(weightHistory, calendar: calendar) {
            if trend < -0.05 {
                return LocalCoachInsight(title: "Тренд веса", message: "Вес за последние 7 дней постепенно снижается. Продолжай текущий темп.", tintName: "green")
            }
            if trend > 0.05 {
                return LocalCoachInsight(title: "Тренд веса", message: "Вес за последние 7 дней растет. Проверь средние калории и соль за неделю.", tintName: "yellow")
            }
        }

        let caloriesLeft = max(targets.calories - totals.calories, 0)
        if caloriesLeft > 0 {
            return LocalCoachInsight(
                title: "Питание",
                message: "До дневной цели осталось \(Int(caloriesLeft.rounded())) ккал. Держи фокус на обычной еде и белке.",
                tintName: "green"
            )
        }

        return LocalCoachInsight(title: "План", message: "Дневная цель закрыта. Завтра просто вернись к обычному режиму без компенсаций.", tintName: "purple")
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

