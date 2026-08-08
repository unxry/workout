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
}

enum NutritionCalculator {
    static func targets(for profile: UserProfile) -> NutritionTargets {
        let sexAdjustment = profile.sex == .male ? 5.0 : -161.0
        let bmr = (10 * profile.currentWeightKg) + (6.25 * profile.heightCm) - (5 * Double(profile.age)) + sexAdjustment
        let tdee = bmr * profile.activityLevel

        let weightDifference = profile.targetWeightKg - profile.currentWeightKg
        let weeklyDelta: Double
        let calories: Double

        switch profile.goal {
        case .fatLoss, .cutting:
            weeklyDelta = -0.45
            calories = max(tdee - 450, bmr * 1.12)
        case .muscleGain:
            weeklyDelta = 0.25
            calories = tdee + 260
        case .recomposition:
            weeklyDelta = weightDifference < 0 ? -0.2 : 0.1
            calories = tdee - 120
        case .maintenance:
            weeklyDelta = 0
            calories = tdee
        }

        let proteinMultiplier = profile.goal == .muscleGain || profile.goal == .recomposition ? 2.0 : 1.8
        let protein = profile.currentWeightKg * proteinMultiplier
        let fat = max(profile.currentWeightKg * 0.8, calories * 0.22 / 9)
        let remainingCalories = max(calories - (protein * 4) - (fat * 9), 0)
        let carbs = remainingCalories / 4
        let water = max(2.0, profile.currentWeightKg * 0.035)

        let weeksToGoal: Double
        if weeklyDelta == 0 {
            weeksToGoal = 12
        } else {
            weeksToGoal = min(max(abs(weightDifference / weeklyDelta), 4), 104)
        }

        let goalDate = Calendar.current.date(byAdding: .day, value: Int(weeksToGoal * 7), to: .now) ?? .now

        return NutritionTargets(
            bmr: bmr.rounded(),
            tdee: tdee.rounded(),
            calories: calories.rounded(),
            protein: protein.rounded(),
            fat: fat.rounded(),
            carbs: carbs.rounded(),
            waterLiters: (water * 10).rounded() / 10,
            weeklyWeightDelta: weeklyDelta,
            goalDate: goalDate
        )
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1.35)
    }
}
