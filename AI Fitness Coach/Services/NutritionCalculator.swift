import Foundation

struct NutritionTargets {
    let bmr: Double
    let tdee: Double
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let waterLiters: Double
    let weeklyWeightDelta: Double
    let goalDate: Date
    let recommendedGoalDate: Date
    let requiredWeeklyWeightDelta: Double
    let calorieFloor: Double
    let isDateTooAggressive: Bool
    let safetyMessage: String?

    init(
        bmr: Double,
        tdee: Double,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        waterLiters: Double,
        weeklyWeightDelta: Double,
        goalDate: Date,
        recommendedGoalDate: Date? = nil,
        requiredWeeklyWeightDelta: Double? = nil,
        calorieFloor: Double = 0,
        isDateTooAggressive: Bool = false,
        safetyMessage: String? = nil
    ) {
        self.bmr = bmr
        self.tdee = tdee
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.waterLiters = waterLiters
        self.weeklyWeightDelta = weeklyWeightDelta
        self.goalDate = goalDate
        self.recommendedGoalDate = recommendedGoalDate ?? goalDate
        self.requiredWeeklyWeightDelta = requiredWeeklyWeightDelta ?? weeklyWeightDelta
        self.calorieFloor = calorieFloor
        self.isDateTooAggressive = isDateTooAggressive
        self.safetyMessage = safetyMessage
    }
}

enum NutritionCalculator {
    static func targets(for profile: UserProfile) -> NutritionTargets {
        let sexAdjustment = profile.sex == .male ? 5.0 : -161.0
        let bmr = (10 * profile.currentWeightKg) + (6.25 * profile.heightCm) - (5 * Double(profile.age)) + sexAdjustment
        let tdee = bmr * profile.activityLevel

        let weightDifference = profile.targetWeightKg - profile.currentWeightKg
        let floor = calorieFloor(for: profile, bmr: bmr)
        let requiredWeeklyDelta = requiredWeeklyWeightDelta(profile: profile, weightDifference: weightDifference)
        let safeWeeklyDelta = safeWeeklyDelta(for: profile, requestedDelta: requiredWeeklyDelta, weightDifference: weightDifference)
        let isTooAggressive = isUnsafe(requestedDelta: requiredWeeklyDelta, safeDelta: safeWeeklyDelta, goal: profile.goal)
        let weeklyDelta = isTooAggressive ? safeWeeklyDelta : requiredWeeklyDelta
        let recommendedDate = recommendedGoalDate(for: profile, safeWeeklyDelta: safeWeeklyDelta, weightDifference: weightDifference)
        let goalDate = isTooAggressive ? recommendedDate : (profile.desiredGoalDate ?? recommendedDate)
        let calories: Double

        switch profile.goal {
        case .fatLoss:
            let requiredDailyDeficit = abs(weeklyDelta) * 7_700 / 7
            calories = max(tdee - requiredDailyDeficit, floor)
        case .muscleGain:
            let requiredDailySurplus = max(weeklyDelta, 0) * 7_700 / 7
            calories = min(tdee + max(requiredDailySurplus, 180), tdee + 380)
        case .recomposition:
            calories = max(tdee - 120, floor)
        case .maintenance:
            calories = tdee
        }

        let proteinMultiplier = profile.goal == .muscleGain || profile.goal == .recomposition ? 2.0 : 1.8
        let protein = profile.currentWeightKg * proteinMultiplier
        let fat = max(profile.currentWeightKg * 0.8, calories * 0.22 / 9)
        let remainingCalories = max(calories - (protein * 4) - (fat * 9), 0)
        let carbs = remainingCalories / 4
        let water = max(2.0, profile.currentWeightKg * 0.035)

        let message = isTooAggressive ? "Эта дата требует слишком быстрого темпа. Я ограничил план безопасными рамками и показал реалистичную дату." : nil

        return NutritionTargets(
            bmr: bmr.rounded(),
            tdee: tdee.rounded(),
            calories: calories.rounded(),
            protein: protein.rounded(),
            fat: fat.rounded(),
            carbs: carbs.rounded(),
            waterLiters: (water * 10).rounded() / 10,
            weeklyWeightDelta: weeklyDelta,
            goalDate: goalDate,
            recommendedGoalDate: recommendedDate,
            requiredWeeklyWeightDelta: requiredWeeklyDelta,
            calorieFloor: floor.rounded(),
            isDateTooAggressive: isTooAggressive,
            safetyMessage: message
        )
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1.35)
    }

    static func goalProgress(for profile: UserProfile) -> Double {
        let start = profile.goalStartWeightKg
        let current = profile.currentWeightKg
        let target = profile.targetWeightKg
        let total = target - start
        guard abs(total) >= 0.1 else { return 1 }
        let moved = current - start
        return min(max(moved / total, 0), 1)
    }

    static func remainingWeight(for profile: UserProfile) -> Double {
        max(abs(profile.currentWeightKg - profile.targetWeightKg), 0)
    }

    private static func calorieFloor(for profile: UserProfile, bmr: Double) -> Double {
        let absoluteFloor: Double
        switch profile.sex {
        case .male:
            absoluteFloor = 1_500
        case .female:
            absoluteFloor = 1_200
        case .notSpecified:
            absoluteFloor = 1_350
        }
        return max(absoluteFloor, bmr * 0.90)
    }

    private static func requiredWeeklyWeightDelta(profile: UserProfile, weightDifference: Double) -> Double {
        guard profile.goal != .maintenance else { return 0 }
        guard abs(weightDifference) >= 0.1 else { return 0 }
        guard let desiredDate = profile.desiredGoalDate else {
            switch profile.goal {
            case .fatLoss: return weightDifference < 0 ? -0.45 : 0
            case .muscleGain: return weightDifference > 0 ? 0.25 : 0
            case .recomposition: return weightDifference < 0 ? -0.2 : 0.1
            case .maintenance: return 0
            }
        }
        let days = max(Calendar.current.dateComponents([.day], from: .now, to: desiredDate).day ?? 0, 7)
        return weightDifference / (Double(days) / 7)
    }

    private static func safeWeeklyDelta(for profile: UserProfile, requestedDelta: Double, weightDifference: Double) -> Double {
        switch profile.goal {
        case .fatLoss:
            guard weightDifference < 0 else { return 0 }
            let maxLoss = min(max(profile.currentWeightKg * 0.0075, 0.35), 0.8)
            let defaultLoss = min(0.45, maxLoss)
            return -min(max(abs(requestedDelta), defaultLoss), maxLoss)
        case .muscleGain:
            guard weightDifference > 0 else { return 0 }
            let maxGain = min(max(profile.currentWeightKg * 0.004, 0.18), 0.35)
            let defaultGain = min(0.25, maxGain)
            return min(max(requestedDelta, defaultGain), maxGain)
        case .recomposition:
            if weightDifference < 0 { return max(requestedDelta, -0.25) }
            if weightDifference > 0 { return min(requestedDelta, 0.15) }
            return 0
        case .maintenance:
            return 0
        }
    }

    private static func isUnsafe(requestedDelta: Double, safeDelta: Double, goal: FitnessGoal) -> Bool {
        switch goal {
        case .fatLoss, .recomposition:
            return requestedDelta < safeDelta - 0.01
        case .muscleGain:
            return requestedDelta > safeDelta + 0.01
        case .maintenance:
            return false
        }
    }

    private static func recommendedGoalDate(for profile: UserProfile, safeWeeklyDelta: Double, weightDifference: Double) -> Date {
        guard abs(weightDifference) >= 0.1, abs(safeWeeklyDelta) >= 0.01 else {
            return profile.desiredGoalDate ?? .now
        }
        let weeks = min(max(abs(weightDifference / safeWeeklyDelta), 1), 156)
        return Calendar.current.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: .now) ?? .now
    }
}

enum NutritionMetricKind: String, Identifiable, CaseIterable {
    case calories
    case protein
    case fat
    case carbs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calories: "Калории"
        case .protein: "Белок"
        case .fat: "Жиры"
        case .carbs: "Углеводы"
        }
    }

    var unit: String {
        switch self {
        case .calories: "ккал"
        default: "г"
        }
    }
}

struct NutritionContribution: Identifiable, Equatable {
    let id: UUID
    let title: String
    let date: Date
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let percentage: Double

    func value(for metric: NutritionMetricKind) -> Double {
        switch metric {
        case .calories: calories
        case .protein: protein
        case .fat: fat
        case .carbs: carbs
        }
    }
}

struct DailyNutritionBreakdown: Equatable {
    let totals: MacroTotals
    let contributions: [NutritionContribution]

    func topContributors(for metric: NutritionMetricKind, limit: Int = 5) -> [NutritionContribution] {
        contributions
            .filter { $0.value(for: metric) > 0 }
            .sorted { $0.value(for: metric) > $1.value(for: metric) }
            .prefix(limit)
            .map { $0 }
    }
}

enum DailyNutritionBreakdownService {
    static func breakdown(for meals: [MealEntry]) -> DailyNutritionBreakdown {
        let totals = MacroTotals(
            calories: meals.reduce(0) { $0 + $1.calories },
            protein: meals.reduce(0) { $0 + $1.protein },
            fat: meals.reduce(0) { $0 + $1.fat },
            carbs: meals.reduce(0) { $0 + $1.carbs }
        )
        let totalCalories = max(totals.calories, 0)
        let contributions = meals.map { meal in
            NutritionContribution(
                id: meal.id,
                title: meal.title,
                date: meal.date,
                calories: meal.calories,
                protein: meal.protein,
                fat: meal.fat,
                carbs: meal.carbs,
                percentage: totalCalories > 0 ? meal.calories / totalCalories : 0
            )
        }
        return DailyNutritionBreakdown(totals: totals, contributions: contributions)
    }
}

extension MacroTotals {
    func value(for metric: NutritionMetricKind) -> Double {
        switch metric {
        case .calories: calories
        case .protein: protein
        case .fat: fat
        case .carbs: carbs
        }
    }
}

extension NutritionTargets {
    func value(for metric: NutritionMetricKind) -> Double {
        switch metric {
        case .calories: calories
        case .protein: protein
        case .fat: fat
        case .carbs: carbs
        }
    }
}
