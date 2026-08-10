import SwiftUI

@main
struct AIFitnessCoachApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var store = LocalDataStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
