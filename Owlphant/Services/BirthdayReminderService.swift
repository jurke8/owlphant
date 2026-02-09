import Foundation
import UserNotifications

struct UpcomingContactReminder: Identifiable {
    enum Kind {
        case coffee
        case stayInTouch(days: Int)
    }

    let id: String
    let contact: Contact
    let date: Date
    let kind: Kind
}

actor BirthdayReminderService {
    static let shared = BirthdayReminderService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let birthdayNotificationPrefix = "birthday."
    private let coffeeNotificationPrefix = "coffee."
    private let stayInTouchNotificationPrefix = "stayintouch."

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func syncAllReminders(for contacts: [Contact], rules: [BirthdayReminderRule]) async {
        let status = await authorizationStatus()
        guard isAuthorizedStatus(status) else {
            return
        }

        await syncBirthdaysAuthorized(for: contacts, rules: rules)
        await syncContactRemindersAuthorized(for: contacts)
    }

    func upcomingContactReminders(for contacts: [Contact]) async -> [UpcomingContactReminder] {
        let contactsByID = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id.uuidString, $0) })
        let pendingRequests = await pendingRequests()
        var reminders: [UpcomingContactReminder] = []

        for request in pendingRequests {
            guard let nextDate = nextTriggerDate(for: request.trigger) else { continue }

            if request.identifier.hasPrefix(coffeeNotificationPrefix),
               let contact = contactFromIdentifier(request.identifier, prefix: coffeeNotificationPrefix, contactsByID: contactsByID) {
                reminders.append(
                    UpcomingContactReminder(id: request.identifier, contact: contact, date: nextDate, kind: .coffee)
                )
                continue
            }

            if request.identifier.hasPrefix(stayInTouchNotificationPrefix),
               let contact = contactFromIdentifier(request.identifier, prefix: stayInTouchNotificationPrefix, contactsByID: contactsByID),
               let days = contact.stayInTouchEveryDays {
                reminders.append(
                    UpcomingContactReminder(id: request.identifier, contact: contact, date: nextDate, kind: .stayInTouch(days: days))
                )
            }
        }

        return reminders.sorted { $0.date < $1.date }
    }

    func syncBirthdays(for contacts: [Contact], rules: [BirthdayReminderRule]) async {
        let status = await authorizationStatus()
        guard isAuthorizedStatus(status) else {
            return
        }

        await syncBirthdaysAuthorized(for: contacts, rules: rules)
    }

    private func syncBirthdaysAuthorized(for contacts: [Contact], rules: [BirthdayReminderRule]) async {
        let existingBirthdayIdentifiers = await pendingIdentifiers(withPrefix: birthdayNotificationPrefix)
        if !existingBirthdayIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: existingBirthdayIdentifiers)
            center.removeDeliveredNotifications(withIdentifiers: existingBirthdayIdentifiers)
        }

        for contact in contacts {
            for rule in rules {
                guard let components = reminderComponents(for: contact, rule: rule) else { continue }

                let content = UNMutableNotificationContent()
                content.title = L10n.tr("notification.birthdayReminder.title")
                content.body = reminderBody(for: contact, rule: rule)
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(
                    identifier: birthdayNotificationIdentifier(for: contact.id, ruleID: rule.id),
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                } catch {
                    continue
                }
            }
        }
    }

    private func syncContactRemindersAuthorized(for contacts: [Contact]) async {
        let existingCoffeeIdentifiers = Set(await pendingIdentifiers(withPrefix: coffeeNotificationPrefix))
        let existingStayInTouchIdentifiers = Set(await pendingIdentifiers(withPrefix: stayInTouchNotificationPrefix))

        var desiredCoffeeIdentifiers = Set<String>()
        var desiredStayInTouchIdentifiers = Set<String>()

        for contact in contacts {
            if let coffeeDate = validCoffeeDate(from: contact.coffeeReminderAt) {
                let coffeeIdentifier = coffeeNotificationIdentifier(for: contact.id, at: coffeeDate.timeIntervalSince1970)
                desiredCoffeeIdentifiers.insert(coffeeIdentifier)
                if !existingCoffeeIdentifiers.contains(coffeeIdentifier) {
                    await scheduleCoffeeReminder(for: contact, at: coffeeDate, identifier: coffeeIdentifier)
                }
            }

            if let stayInTouchDays = validStayInTouchInterval(from: contact.stayInTouchEveryDays) {
                let stayInTouchIdentifier = stayInTouchNotificationIdentifier(for: contact.id, everyDays: stayInTouchDays)
                desiredStayInTouchIdentifiers.insert(stayInTouchIdentifier)
                if !existingStayInTouchIdentifiers.contains(stayInTouchIdentifier) {
                    await scheduleStayInTouchReminder(for: contact, everyDays: stayInTouchDays, identifier: stayInTouchIdentifier)
                }
            }
        }

        let staleCoffeeIdentifiers = Array(existingCoffeeIdentifiers.subtracting(desiredCoffeeIdentifiers))
        if !staleCoffeeIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleCoffeeIdentifiers)
            center.removeDeliveredNotifications(withIdentifiers: staleCoffeeIdentifiers)
        }

        let staleStayInTouchIdentifiers = Array(existingStayInTouchIdentifiers.subtracting(desiredStayInTouchIdentifiers))
        if !staleStayInTouchIdentifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleStayInTouchIdentifiers)
            center.removeDeliveredNotifications(withIdentifiers: staleStayInTouchIdentifiers)
        }
    }

    private func scheduleCoffeeReminder(for contact: Contact, at date: Date, identifier: String) async {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notification.coffeeReminder.title")
        content.body = L10n.format("notification.coffeeReminder.body", displayName(for: contact))
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    private func scheduleStayInTouchReminder(for contact: Contact, everyDays days: Int, identifier: String) async {
        let interval = TimeInterval(days * 24 * 60 * 60)
        let content = UNMutableNotificationContent()
        content.title = L10n.tr("notification.stayInTouchReminder.title")
        content.body = L10n.format("notification.stayInTouchReminder.body", displayName(for: contact), days)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    private func pendingIdentifiers(withPrefix prefix: String) async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let identifiers = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(prefix) }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func contactFromIdentifier(_ identifier: String, prefix: String, contactsByID: [String: Contact]) -> Contact? {
        let payload = identifier.dropFirst(prefix.count)
        let contactID = payload.split(separator: ".", omittingEmptySubsequences: true).first.map(String.init)
        guard let contactID else { return nil }
        return contactsByID[contactID]
    }

    private func nextTriggerDate(for trigger: UNNotificationTrigger?) -> Date? {
        guard let trigger else { return nil }
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return intervalTrigger.nextTriggerDate()
        }
        return nil
    }

    private func birthdayNotificationIdentifier(for contactID: UUID, ruleID: UUID) -> String {
        "\(birthdayNotificationPrefix)\(contactID.uuidString).\(ruleID.uuidString)"
    }

    private func coffeeNotificationIdentifier(for contactID: UUID, at timestamp: TimeInterval) -> String {
        "\(coffeeNotificationPrefix)\(contactID.uuidString).\(Int(timestamp))"
    }

    private func stayInTouchNotificationIdentifier(for contactID: UUID, everyDays days: Int) -> String {
        "\(stayInTouchNotificationPrefix)\(contactID.uuidString).\(days)"
    }

    private func validCoffeeDate(from timestamp: TimeInterval?) -> Date? {
        guard let timestamp else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        return date > Date() ? date : nil
    }

    private func validStayInTouchInterval(from days: Int?) -> Int? {
        guard let days, days > 0 else { return nil }
        return min(days, 365)
    }

    private func isAuthorizedStatus(_ status: UNAuthorizationStatus) -> Bool {
        if status == .authorized || status == .provisional {
            return true
        }
#if os(iOS)
        if #available(iOS 14.0, *), status == .ephemeral {
            return true
        }
#endif
        return false
    }

    private func reminderBody(for contact: Contact, rule: BirthdayReminderRule) -> String {
        let displayName = displayName(for: contact)

        switch rule.daysBeforeBirthday {
        case 0:
            return L10n.format("notification.birthday.today", displayName)
        case 1:
            return L10n.format("notification.birthday.tomorrow", displayName)
        default:
            return L10n.format("notification.birthday.inDays", displayName, rule.daysBeforeBirthday)
        }
    }

    private func displayName(for contact: Contact) -> String {
        let first = contact.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = contact.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = contact.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return combined.isEmpty ? (nickname.isEmpty ? L10n.tr("notification.contact.this") : nickname) : combined
    }

    private func reminderComponents(for contact: Contact, rule: BirthdayReminderRule) -> DateComponents? {
        guard
            let birthday = contact.birthday?.trimmingCharacters(in: .whitespacesAndNewlines),
            !birthday.isEmpty,
            let value = BirthdayValue(rawValue: birthday),
            let month = value.month,
            let day = value.day
        else {
            return nil
        }

        guard
            let fixedDate = calendar.date(from: DateComponents(year: 2001, month: month, day: day)),
            let shiftedDate = calendar.date(byAdding: .day, value: -rule.daysBeforeBirthday, to: fixedDate)
        else {
            return nil
        }

        let shifted = calendar.dateComponents([.month, .day], from: shiftedDate)
        guard let shiftedMonth = shifted.month, let shiftedDay = shifted.day else { return nil }
        return DateComponents(month: shiftedMonth, day: shiftedDay, hour: rule.hour, minute: rule.minute)
    }
}
