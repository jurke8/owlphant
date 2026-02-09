import Foundation
import UserNotifications

actor BirthdayReminderService {
    static let shared = BirthdayReminderService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private let notificationPrefix = "birthday."

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

    func syncBirthdays(for contacts: [Contact], rules: [BirthdayReminderRule]) async {
        let status = await authorizationStatus()
        guard isAuthorizedStatus(status) else {
            return
        }

        let existingBirthdayIdentifiers = await pendingBirthdayIdentifiers()
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
                    identifier: notificationIdentifier(for: contact.id, ruleID: rule.id),
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

    private func pendingBirthdayIdentifiers() async -> [String] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                let identifiers = requests
                    .map(\.identifier)
                    .filter { $0.hasPrefix(self.notificationPrefix) }
                continuation.resume(returning: identifiers)
            }
        }
    }

    private func notificationIdentifier(for contactID: UUID, ruleID: UUID) -> String {
        "\(notificationPrefix)\(contactID.uuidString).\(ruleID.uuidString)"
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
        let first = contact.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = contact.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = "\(first) \(last)".trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = contact.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = combined.isEmpty ? (nickname.isEmpty ? L10n.tr("notification.contact.this") : nickname) : combined

        switch rule.daysBeforeBirthday {
        case 0:
            return L10n.format("notification.birthday.today", displayName)
        case 1:
            return L10n.format("notification.birthday.tomorrow", displayName)
        default:
            return L10n.format("notification.birthday.inDays", displayName, rule.daysBeforeBirthday)
        }
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
