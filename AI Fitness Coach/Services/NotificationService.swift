import Foundation
import UserNotifications

final class NotificationService {
    private enum Identifier {
        static let dailyCoach = "daily-coach-checkin"
        static let waterPrefix = "water-reminder"
        static let mealPrefix = "meal-reminder"
        static let workout = "workout-reminder"
        static let weight = "weight-reminder"
        static let sleep = "sleep-reminder"
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleDailyCoachCheckIn(hour: Int = 20, minute: Int = 30) async {
        await scheduleRepeating(
            id: Identifier.dailyCoach,
            title: "AI Coach",
            body: "Пора коротко сверить питание, шаги и восстановление за день.",
            hour: hour,
            minute: minute
        )
    }

    func scheduleDefaultReminders() async {
        let center = UNUserNotificationCenter.current()
        let ids = [Identifier.dailyCoach, Identifier.workout, Identifier.weight, Identifier.sleep]
            + stride(from: 9, through: 21, by: 2).map { "\(Identifier.waterPrefix)-\($0)" }
            + [9, 14, 19].map { "\(Identifier.mealPrefix)-\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for hour in stride(from: 9, through: 21, by: 2) {
            await scheduleRepeating(
                id: "\(Identifier.waterPrefix)-\(hour)",
                title: "Вода",
                body: "Выпей воды и отметь стакан в дневнике.",
                hour: hour,
                minute: 0
            )
        }

        for (hour, title) in [(9, "Завтрак"), (14, "Обед"), (19, "Ужин")] {
            await scheduleRepeating(
                id: "\(Identifier.mealPrefix)-\(hour)",
                title: title,
                body: "Добавь прием пищи, чтобы AI Coach видел реальную картину дня.",
                hour: hour,
                minute: 0
            )
        }

        await scheduleRepeating(
            id: Identifier.weight,
            title: "Вес",
            body: "Взвесься утром и обнови прогресс.",
            hour: 8,
            minute: 30
        )
        await scheduleRepeating(
            id: Identifier.workout,
            title: "Тренировка",
            body: "Проверь план тренировки и отметь выполненное.",
            hour: 19,
            minute: 0
        )
        await scheduleRepeating(
            id: Identifier.sleep,
            title: "Сон",
            body: "Пора готовиться ко сну, восстановление тоже часть прогресса.",
            hour: 23,
            minute: 0
        )
        await scheduleDailyCoachCheckIn()
    }

    func pendingReminderCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests().count
    }

    private func scheduleRepeating(id: String, title: String, body: String, hour: Int, minute: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var date = DateComponents()
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
