import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: CoachTab = .home
    @Published var apiKeyStatus: APIKeyStatus = .unknown
    @Published var healthAuthorization: HealthAuthorizationState = .unknown

    let aiClient = OpenAIClient()
    let healthKit = HealthKitService()
    let notifications = NotificationService()

    init() {
        apiKeyStatus = KeychainStore.shared.readOpenAIKey().isEmpty ? .missing : .configured
    }

    func saveOpenAIKey(_ key: String) {
        KeychainStore.shared.saveOpenAIKey(key.trimmingCharacters(in: .whitespacesAndNewlines))
        apiKeyStatus = key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .missing : .configured
    }
}

enum APIKeyStatus {
    case unknown
    case missing
    case configured
}

enum HealthAuthorizationState {
    case unknown
    case unavailable
    case requested
}

enum CoachTab: String, CaseIterable, Identifiable {
    case home
    case nutrition
    case coach
    case progress
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Главная"
        case .nutrition: "Питание"
        case .coach: "ИИ-помощник"
        case .progress: "Тренировки"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .nutrition: "fork.knife"
        case .coach: "robot"
        case .progress: "dumbbell"
        case .profile: "person"
        }
    }
}
