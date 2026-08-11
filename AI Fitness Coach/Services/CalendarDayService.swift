import Foundation

struct DayContext: Equatable {
    var calendar: Calendar
    var date: Date

    init(date: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.locale = Locale.current
        self.calendar = calendar
        self.date = date
    }

    var start: Date {
        calendar.startOfDay(for: date)
    }

    var interval: DateInterval {
        calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: start, duration: 86_400)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    func contains(_ candidate: Date) -> Bool {
        interval.contains(candidate)
    }

    func sameDay(as other: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: other)
    }
}

enum DailyTotalsCalculator {
    static func macroTotals(for meals: [MealEntry], day: DayContext) -> MacroTotals {
        let dayMeals = meals.filter { day.contains($0.date) }
        return MacroTotals(
            calories: dayMeals.reduce(0) { $0 + $1.calories },
            protein: dayMeals.reduce(0) { $0 + $1.protein },
            fat: dayMeals.reduce(0) { $0 + $1.fat },
            carbs: dayMeals.reduce(0) { $0 + $1.carbs }
        )
    }
}
