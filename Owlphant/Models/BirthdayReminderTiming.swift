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

struct BirthdayReminderRule: Codable, Identifiable, Hashable {
    var id: UUID
    var daysBeforeBirthday: Int
    var hour: Int
    var minute: Int

    nonisolated static let storageKey = "birthday.reminder.rules.v1"
    nonisolated static let defaultRule = BirthdayReminderRule(id: UUID(), daysBeforeBirthday: 0, hour: 9, minute: 0)

    var signature: String {
        "\(daysBeforeBirthday)-\(hour)-\(minute)"
    }

    var title: String {
        let time = Self.timeFormatter.string(from: Self.timeDate(hour: hour, minute: minute))
        if daysBeforeBirthday == 0 {
            return "On birthday at \(time)"
        }
        if daysBeforeBirthday == 1 {
            return "1 day before at \(time)"
        }
        return "\(daysBeforeBirthday) days before at \(time)"
    }

    static func loadFromDefaults(_ defaults: UserDefaults = .standard) -> [BirthdayReminderRule] {
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([BirthdayReminderRule].self, from: data) {
            return sanitizedRules(decoded)
        }

        if let migrated = migratedLegacyRules(defaults), !migrated.isEmpty {
            saveToDefaults(migrated, defaults)
            return migrated
        }

        let fallback = [defaultRule]
        saveToDefaults(fallback, defaults)
        return fallback
    }

    static func saveToDefaults(_ rules: [BirthdayReminderRule], _ defaults: UserDefaults = .standard) {
        let sanitized = sanitizedRules(rules)
        guard let data = try? JSONEncoder().encode(sanitized) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func sanitizedRules(_ rules: [BirthdayReminderRule]) -> [BirthdayReminderRule] {
        var signatures = Set<String>()
        return rules.compactMap { rule -> BirthdayReminderRule? in
            let daysBeforeBirthday = min(max(rule.daysBeforeBirthday, 0), 365)
            let hour = min(max(rule.hour, 0), 23)
            let minute = min(max(rule.minute, 0), 59)
            let normalized = BirthdayReminderRule(id: rule.id, daysBeforeBirthday: daysBeforeBirthday, hour: hour, minute: minute)
            if signatures.contains(normalized.signature) {
                return nil
            }
            signatures.insert(normalized.signature)
            return normalized
        }
    }

    private static func migratedLegacyRules(_ defaults: UserDefaults) -> [BirthdayReminderRule]? {
        guard let legacyRaw = defaults.string(forKey: BirthdayReminderTiming.storageKey) else {
            return nil
        }

        let legacyTiming = BirthdayReminderTiming.fromStored(legacyRaw)
        let rule: BirthdayReminderRule
        switch legacyTiming {
        case .onBirthdayAt9AM:
            rule = BirthdayReminderRule(id: UUID(), daysBeforeBirthday: 0, hour: 9, minute: 0)
        case .dayBeforeAt9AM:
            rule = BirthdayReminderRule(id: UUID(), daysBeforeBirthday: 1, hour: 9, minute: 0)
        case .dayBeforeAt2PM:
            rule = BirthdayReminderRule(id: UUID(), daysBeforeBirthday: 1, hour: 14, minute: 0)
        }

        return [rule]
    }

    private static func timeDate(hour: Int, minute: Int) -> Date {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
    }

    private static let calendar = Calendar.current

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("h:mm a")
        return formatter
    }()
}
