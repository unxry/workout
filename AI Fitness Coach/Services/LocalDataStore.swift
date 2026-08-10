import Combine
import Foundation

@MainActor
final class LocalDataStore: ObservableObject {
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var meals: [MealEntry] = []
    @Published private(set) var metrics: [DailyMetric] = []
    @Published private(set) var memories: [CoachMemory] = []
    @Published private(set) var workouts: [WorkoutLog] = []

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
            memories = snapshot.memories
            workouts = snapshot.workouts
            sort()
        } catch {
            assertionFailure("LocalDataStore decode failed: \(error)")
        }
    }

    private func save() {
        do {
            let folder = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let snapshot = Snapshot(profiles: profiles, meals: meals, metrics: metrics, memories: memories, workouts: workouts)
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
        memories.sort { $0.createdAt > $1.createdAt }
        workouts.sort { $0.date > $1.date }
    }
}

private struct Snapshot: Codable {
    var profiles: [UserProfile]
    var meals: [MealEntry]
    var metrics: [DailyMetric]
    var memories: [CoachMemory]
    var workouts: [WorkoutLog]
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
