import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "Похудение"
    case muscleGain = "Набор массы"
    case recomposition = "Рекомпозиция"
    case maintenance = "Поддержание"

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

struct FoodProduct: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var aliases: [String]
    var category: String
    var kcalPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var carbsPer100g: Double
    var fiberPer100g: Double?
    var sugarPer100g: Double?
    var barcode: String?
    var brand: String?
    var packageGrams: Double?
    var source: String
    var sourceURL: URL?
    var isFavorite: Bool
    var lastUsedAt: Date?

    init(
        id: String,
        name: String,
        aliases: [String] = [],
        category: String,
        kcalPer100g: Double,
        proteinPer100g: Double,
        fatPer100g: Double,
        carbsPer100g: Double,
        fiberPer100g: Double? = nil,
        sugarPer100g: Double? = nil,
        barcode: String? = nil,
        brand: String? = nil,
        packageGrams: Double? = nil,
        source: String = "Локальная база",
        sourceURL: URL? = nil,
        isFavorite: Bool = false,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.fatPer100g = fatPer100g
        self.carbsPer100g = carbsPer100g
        self.fiberPer100g = fiberPer100g
        self.sugarPer100g = sugarPer100g
        self.barcode = barcode
        self.brand = brand
        self.packageGrams = packageGrams
        self.source = source
        self.sourceURL = sourceURL
        self.isFavorite = isFavorite
        self.lastUsedAt = lastUsedAt
    }
}

enum FoodRecognitionStatus: String, Codable, Equatable {
    case food = "FOOD"
    case notFood = "NOT_FOOD"
    case uncertain = "UNCERTAIN"
}

struct FoodEstimateItem: Codable, Equatable {
    var productID: String?
    var name: String
    var estimatedGrams: Double
    var confidence: Double
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case name
        case estimatedGrams = "estimated_grams"
        case confidence
        case calories
        case protein
        case fat
        case carbs
    }
}

struct NutritionEstimateTotal: Codable, Equatable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

struct FoodPhotoAnalysis: Codable, Equatable {
    var status: FoodRecognitionStatus
    var confidence: Double
    var message: String
    var items: [FoodEstimateItem]
    var total: NutritionEstimateTotal?

    var isFood: Bool {
        status == .food
    }
}
