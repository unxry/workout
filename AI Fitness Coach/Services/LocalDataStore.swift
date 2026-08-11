import Combine
import Foundation

@MainActor
final class LocalDataStore: ObservableObject {
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var metrics: [DailyMetric] = []
    @Published private(set) var waterEntries: [WaterEntry] = []
    @Published private(set) var memories: [CoachMemory] = []
    @Published private(set) var workouts: [WorkoutLog] = []
    @Published private(set) var foodProducts: [FoodProduct] = NutritionDatabaseService.defaultProducts

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            self.fileURL = (documents ?? FileManager.default.temporaryDirectory).appendingPathComponent("ai-fitness-coach-store.json")
        }
        load()
    }

    var profile: UserProfile? {
        profiles.sorted { $0.createdAt < $1.createdAt }.first
    }

    func createProfile(_ profile: UserProfile, initialWeight: Double) {
        profiles = [profile]
        metrics = [DailyMetric(date: .now, weightKg: initialWeight)]
        save()
    }

    func updateProfile(_ update: (UserProfile) -> Void) {
        guard let profile else { return }
        update(profile)
        profile.updatedAt = .now
        objectWillChange.send()
        save()
    }

    func addMeal(_ meal: MealEntry) {
        meals.insert(meal, at: 0)
        sort()
        save()
    }

    func deleteMeal(_ meal: MealEntry) {
        meals.removeAll { $0.id == meal.id }
        save()
    }

    func addMemory(_ memory: CoachMemory) {
        memories.insert(memory, at: 0)
        sort()
        save()
    }

    func addWorkout(_ workout: WorkoutLog) {
        workouts.insert(workout, at: 0)
        sort()
        save()
    }

    func upsertFoodProduct(_ product: FoodProduct) {
        if let index = foodProducts.firstIndex(where: { $0.id == product.id || ($0.barcode != nil && $0.barcode == product.barcode) }) {
            foodProducts[index] = product
        } else {
            foodProducts.insert(product, at: 0)
        }
        sort()
        save()
    }

    func markFoodProductUsed(_ productID: String) {
        guard let index = foodProducts.firstIndex(where: { $0.id == productID }) else { return }
        foodProducts[index].lastUsedAt = .now
        sort()
        save()
    }

    func addWater(liters: Double, on date: Date = .now, calendar: Calendar = .current) {
        guard liters > 0 else { return }
        let metric = metricForDay(date, calendar: calendar)
        metric.waterLiters += liters
        waterEntries.insert(WaterEntry(date: date, liters: liters), at: 0)
        objectWillChange.send()
        sort()
        save()
    }

    func updateActivity(steps: Int, activeEnergyKcal: Double, on date: Date = .now, calendar: Calendar = .current) {
        let metric = metricForDay(date, calendar: calendar)
        metric.steps = max(steps, 0)
        metric.activeEnergyKcal = max(activeEnergyKcal, 0)
        objectWillChange.send()
        sort()
        save()
    }

    func recordWeight(_ weightKg: Double, on date: Date = .now, calendar: Calendar = .current) {
        guard (35...250).contains(weightKg) else { return }
        let metric = metricForDay(date, calendar: calendar)
        metric.weightKg = weightKg
        updateProfile { profile in
            profile.currentWeightKg = weightKg
        }
        objectWillChange.send()
        sort()
        save()
    }

    func deleteDiaryProgressAndWorkouts() {
        meals.removeAll()
        metrics.removeAll()
        workouts.removeAll()
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let snapshot = try JSONDecoder.localStore.decode(Snapshot.self, from: data)
            profiles = snapshot.profiles
            meals = snapshot.meals
            metrics = snapshot.metrics
            waterEntries = snapshot.waterEntries
            memories = snapshot.memories
            workouts = snapshot.workouts
            foodProducts = NutritionDatabaseService.mergedProducts(local: snapshot.foodProducts)
            sort()
        } catch {
            assertionFailure("LocalDataStore decode failed: \(error)")
        }
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let snapshot = Snapshot(profiles: profiles, meals: meals, metrics: metrics, waterEntries: waterEntries, memories: memories, workouts: workouts, foodProducts: foodProducts)
            let data = try JSONEncoder.localStore.encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("LocalDataStore save failed: \(error)")
        }
    }

    private func sort() {
        profiles.sort { $0.createdAt < $1.createdAt }
        meals.sort { $0.date > $1.date }
        metrics.sort { $0.date < $1.date }
        waterEntries.sort { $0.date > $1.date }
        memories.sort { $0.createdAt > $1.createdAt }
        workouts.sort { $0.date > $1.date }
        foodProducts.sort {
            switch ($0.lastUsedAt, $1.lastUsedAt) {
            case let (lhs?, rhs?): return lhs > rhs
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func metricForDay(_ date: Date, calendar: Calendar) -> DailyMetric {
        if let existing = metrics.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return existing
        }
        let weight = profile?.currentWeightKg ?? metrics.last?.weightKg ?? 0
        let metric = DailyMetric(date: date, weightKg: weight)
        metrics.append(metric)
        return metric
    }
}

private struct Snapshot: Codable {
    var profiles: [UserProfile]
    var meals: [MealEntry]
    var metrics: [DailyMetric]
    var waterEntries: [WaterEntry]
    var memories: [CoachMemory]
    var workouts: [WorkoutLog]
    var foodProducts: [FoodProduct]

    enum CodingKeys: String, CodingKey {
        case profiles
        case meals
        case metrics
        case waterEntries
        case memories
        case workouts
        case foodProducts
    }

    init(profiles: [UserProfile], meals: [MealEntry], metrics: [DailyMetric], memories: [CoachMemory], workouts: [WorkoutLog], foodProducts: [FoodProduct]) {
        self.profiles = profiles
        self.meals = meals
        self.metrics = metrics
        self.waterEntries = []
        self.memories = memories
        self.workouts = workouts
        self.foodProducts = foodProducts
    }

    init(profiles: [UserProfile], meals: [MealEntry], metrics: [DailyMetric], waterEntries: [WaterEntry], memories: [CoachMemory], workouts: [WorkoutLog], foodProducts: [FoodProduct]) {
        self.profiles = profiles
        self.meals = meals
        self.metrics = metrics
        self.waterEntries = waterEntries
        self.memories = memories
        self.workouts = workouts
        self.foodProducts = foodProducts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try container.decodeIfPresent([UserProfile].self, forKey: .profiles) ?? []
        meals = try container.decodeIfPresent([MealEntry].self, forKey: .meals) ?? []
        metrics = try container.decodeIfPresent([DailyMetric].self, forKey: .metrics) ?? []
        waterEntries = try container.decodeIfPresent([WaterEntry].self, forKey: .waterEntries) ?? []
        memories = try container.decodeIfPresent([CoachMemory].self, forKey: .memories) ?? []
        workouts = try container.decodeIfPresent([WorkoutLog].self, forKey: .workouts) ?? []
        foodProducts = try container.decodeIfPresent([FoodProduct].self, forKey: .foodProducts) ?? []
    }
}

private extension JSONEncoder {
    static var localStore: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var localStore: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
