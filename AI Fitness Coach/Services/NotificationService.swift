import Foundation
import UserNotifications

final class NotificationService {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleDailyCoachCheckIn(hour: Int = 20, minute: Int = 30) async {
        let content = UNMutableNotificationContent()
        content.title = "AI Coach"
        content.body = "Пора коротко сверить питание, шаги и восстановление за день."
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-coach-checkin", content: content, trigger: trigger)

        try? await UNUserNotificationCenter.current().add(request)
    }
}
