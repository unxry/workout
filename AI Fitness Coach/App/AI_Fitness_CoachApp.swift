import SwiftData
import SwiftUI

@main
struct AIFitnessCoachApp: App {
    private let modelContainer: ModelContainer

    @StateObject private var appState = AppState()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: UserProfile.self,
                DailyMetric.self,
                MealEntry.self,
                CoachMemory.self,
                WorkoutLog.self
            )
        } catch {
            fatalError("SwiftData container failed: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
