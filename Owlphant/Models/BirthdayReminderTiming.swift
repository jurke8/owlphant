import Foundation

enum BirthdayReminderTiming: String, CaseIterable, Identifiable {
    case onBirthdayAt9AM = "on_birthday_9am"
    case dayBeforeAt9AM = "day_before_9am"
    case dayBeforeAt2PM = "day_before_2pm"

    static let storageKey = "birthday.reminder.timing"
    static let defaultValue: BirthdayReminderTiming = .onBirthdayAt9AM

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onBirthdayAt9AM:
            "On birthday at 9:00 AM"
        case .dayBeforeAt9AM:
            "Day before at 9:00 AM"
        case .dayBeforeAt2PM:
            "Day before at 2:00 PM"
        }
    }

    static func fromStored(_ rawValue: String) -> BirthdayReminderTiming {
        BirthdayReminderTiming(rawValue: rawValue) ?? defaultValue
    }
}
