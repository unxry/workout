import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: CoachTab = .home
    @Published var healthAuthorization: HealthAuthorizationState = .unknown

    let healthKit = HealthKitService()
    let notifications = NotificationService()
}

enum HealthAuthorizationState {
    case unknown
    case unavailable
    case requested
}

enum CoachTab: String, CaseIterable, Identifiable {
    case home
    case nutrition
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Главная"
        case .nutrition: "Питание"
        case .profile: "Профиль"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .nutrition: "fork.knife"
        case .profile: "person"
        }
    }
}
