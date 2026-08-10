import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "Похудение"
    case muscleGain = "Набор массы"
    case recomposition = "Рекомпозиция"
    case maintenance = "Поддержание"
    case cutting = "Сушка"

    var id: String { rawValue }
}

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case female = "Женский"
    case male = "Мужской"
    case notSpecified = "Не указано"

    var id: String { rawValue }
}

final class UserProfile: Identifiable, Codable {
    var id: UUID
    var name: String
    var birthDate: Date
    var sexRawValue: String
    var heightCm: Double
    var currentWeightKg: Double
    var targetWeightKg: Double
    var goalRawValue: String
    var activityLevel: Double
    var trainingDaysPerWeek: Int
    var preferredMealsPerDay: Int
    var sleepTime: Date
    var wakeTime: Date
    var allergies: String
    var excludedFoods: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        birthDate: Date,
        sex: BiologicalSex,
        heightCm: Double,
        currentWeightKg: Double,
        targetWeightKg: Double,
        goal: FitnessGoal,
        activityLevel: Double,
        trainingDaysPerWeek: Int,
        preferredMealsPerDay: Int,
        sleepTime: Date,
        wakeTime: Date,
        allergies: String,
        excludedFoods: String
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.sexRawValue = sex.rawValue
        self.heightCm = heightCm
        self.currentWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.goalRawValue = goal.rawValue
        self.activityLevel = activityLevel
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.preferredMealsPerDay = preferredMealsPerDay
        self.sleepTime = sleepTime
        self.wakeTime = wakeTime
        self.allergies = allergies
        self.excludedFoods = excludedFoods
        self.createdAt = .now
        self.updatedAt = .now
    }

    var sex: BiologicalSex {
        BiologicalSex(rawValue: sexRawValue) ?? .notSpecified
    }

    var goal: FitnessGoal {
        FitnessGoal(rawValue: goalRawValue) ?? .maintenance
    }

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 30
    }
}

final class DailyMetric: Identifiable, Codable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var steps: Int
    var waterLiters: Double
    var sleepHours: Double
    var moodScore: Int
    var activeEnergyKcal: Double

    init(
        id: UUID = UUID(),
        date: Date,
        weightKg: Double,
        steps: Int = 0,
        waterLiters: Double = 0,
        sleepHours: Double = 0,
        moodScore: Int = 3,
        activeEnergyKcal: Double = 0
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.steps = steps
        self.waterLiters = waterLiters
        self.sleepHours = sleepHours
        self.moodScore = moodScore
        self.activeEnergyKcal = activeEnergyKcal
    }
}

final class MealEntry: Identifiable, Codable {
    var id: UUID
    var date: Date
    var title: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var source: String

    init(
        id: UUID = UUID(),
        date: Date = .now,
        title: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        source: String = "manual"
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.source = source
    }
}

final class CoachMemory: Identifiable, Codable {
    var id: UUID
    var createdAt: Date
    var kind: String
    var content: String
    var importance: Double

    init(id: UUID = UUID(), createdAt: Date = .now, kind: String, content: String, importance: Double) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.content = content
        self.importance = importance
    }
}

final class WorkoutLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var title: String
    var durationMinutes: Int
    var calories: Double
    var notes: String

    init(id: UUID = UUID(), date: Date = .now, title: String, durationMinutes: Int, calories: Double, notes: String = "") {
        self.id = id
        self.date = date
        self.title = title
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.notes = notes
    }
}
