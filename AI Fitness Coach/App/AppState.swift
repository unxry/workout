import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: CoachTab = .home
    @Published var apiKeyStatus: APIKeyStatus = .unknown
    @Published var healthAuthorization: HealthAuthorizationState = .unknown
    @Published var pendingAlicePrompt: String?

    let aiClient: AIProvider = YandexAIProvider()
    let healthKit = HealthKitService()
    let notifications = NotificationService()

    init() {
        apiKeyStatus = APIKeyStatus.fromStoredConfiguration()
    }

    func saveAliceConfiguration(apiKey: String, folderID: String) {
        KeychainStore.shared.saveYandexAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
        KeychainStore.shared.saveYandexFolderID(folderID.trimmingCharacters(in: .whitespacesAndNewlines))
        apiKeyStatus = APIKeyStatus.fromStoredConfiguration()
    }

    func deleteAliceConfiguration() {
        KeychainStore.shared.deleteYandexAPIKey()
        KeychainStore.shared.deleteYandexFolderID()
        apiKeyStatus = .missing
    }

    func refreshAliceStatus() {
        apiKeyStatus = APIKeyStatus.fromStoredConfiguration()
    }

    func openAlice(with prompt: String) {
        pendingAlicePrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedTab = .coach
    }

    func consumePendingAlicePrompt() -> String? {
        defer { pendingAlicePrompt = nil }
        guard let prompt = pendingAlicePrompt, !prompt.isEmpty else { return nil }
        return prompt
    }
}

enum APIKeyStatus {
    case unknown
    case missing
    case configured

    static func fromStoredConfiguration() -> APIKeyStatus {
        let key = KeychainStore.shared.readYandexAPIKey().trimmingCharacters(in: .whitespacesAndNewlines)
        let folderID = KeychainStore.shared.readYandexFolderID().trimmingCharacters(in: .whitespacesAndNewlines)
        return key.isEmpty || folderID.isEmpty ? .missing : .configured
    }

    var isConfigured: Bool {
        self == .configured
    }
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
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Главная"
        case .nutrition: "Питание"
        case .coach: "Алиса"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .nutrition: "fork.knife"
        case .coach: "sparkles"
        case .profile: "person"
        }
    }
}
