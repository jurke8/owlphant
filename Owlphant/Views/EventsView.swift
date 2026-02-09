import SwiftUI

struct EventsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var reminderRules: [BirthdayReminderRule] = []
    @State private var upcomingContactReminders: [UpcomingContactReminder] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text(L10n.tr("events.upcoming.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(contactCountText)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            if upcomingBirthdayContacts.isEmpty {
                                Text(L10n.tr("events.upcoming.empty"))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                ForEach(upcomingBirthdayContacts.prefix(8)) { contact in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.displayName)
                                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(L10n.format("events.item.birthday", birthdayDetails(for: contact)))
                                                .font(.system(.footnote, design: .rounded))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        Text(nextReminderLabel(for: contact))
                                            .multilineTextAlignment(.trailing)
                                            .font(.system(.footnote, design: .rounded))
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                            }
                        }

                        SectionCard {
                            Text(L10n.tr("events.contactReminders.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            if upcomingContactReminders.isEmpty {
                                Text(L10n.tr("events.contactReminders.empty"))
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                ForEach(upcomingContactReminders.prefix(8)) { reminder in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(reminder.contact.displayName)
                                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(reminderLabel(for: reminder))
                                                .font(.system(.footnote, design: .rounded))
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        Spacer()
                                        Text(Self.reminderFormatter.string(from: reminder.date))
                                            .multilineTextAlignment(.trailing)
                                            .font(.system(.footnote, design: .rounded))
                                            .foregroundStyle(AppTheme.muted)
                                    }
                                }
                            }
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.tr("tab.events"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await refreshStatusAndSync()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshStatusAndSync() }
        }
    }

    private var birthdayContacts: [Contact] {
        viewModel.contacts
            .filter { contact in
                guard let birthday = contact.birthday else { return false }
                return BirthdayValue(rawValue: birthday) != nil
            }
    }

    private var upcomingBirthdayContacts: [Contact] {
        birthdayContacts.sorted {
            let lhsDate = nextBirthdayDate(for: $0) ?? .distantFuture
            let rhsDate = nextBirthdayDate(for: $1) ?? .distantFuture
            return lhsDate < rhsDate
        }
    }

    private func refreshStatusAndSync() async {
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncAllReminders(for: viewModel.contacts, rules: reminderRules)
        upcomingContactReminders = await BirthdayReminderService.shared.upcomingContactReminders(for: viewModel.contacts)
    }

    private func reminderLabel(for reminder: UpcomingContactReminder) -> String {
        switch reminder.kind {
        case .coffee:
            return "☕️ \(L10n.tr("events.contactReminders.coffee"))"
        case let .stayInTouch(days):
            return "🤙 \(L10n.format("events.contactReminders.stayInTouch", days))"
        }
    }

    private func displayDate(_ value: String?) -> String {
        guard let value, let birthday = BirthdayValue(rawValue: value) else { return "-" }
        return birthday.displayText
    }

    private func birthdayDetails(for contact: Contact) -> String {
        let dateText = displayDate(contact.birthday)
        guard let upcomingAge = upcomingAge(for: contact) else {
            return dateText
        }
        let ageText = L10n.format("events.item.turningAge", upcomingAge)
        return "\(dateText) (\(ageText))"
    }

    private func upcomingAge(for contact: Contact) -> Int? {
        guard
            let value = contact.birthday,
            let birthday = BirthdayValue(rawValue: value),
            birthday.isFullDate,
            let nextBirthday = nextBirthdayDate(for: contact)
        else {
            return nil
        }

        let birthYear = birthday.year
        let nextBirthdayYear = Self.calendar.component(.year, from: nextBirthday)
        let age = nextBirthdayYear - birthYear
        return age > 0 ? age : nil
    }

    private func nextReminderLabel(for contact: Contact) -> String {
        let next = reminderRules
            .compactMap { nextReminderDate(for: contact, rule: $0) }
            .min()
        guard let date = next else { return L10n.tr("events.next.none") }
        return L10n.format("events.next.value", Self.reminderFormatter.string(from: date))
    }

    private var contactCountText: String {
        L10n.format("events.count", upcomingBirthdayContacts.count)
    }

    private func nextBirthdayDate(for contact: Contact) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = BirthdayValue(rawValue: birthdayValue),
            let month = birthday.month,
            let day = birthday.day
        else {
            return nil
        }

        return Self.calendar.nextDate(
            after: Date(),
            matching: DateComponents(month: month, day: day, hour: 0, minute: 0),
            matchingPolicy: .nextTime
        )
    }

    private func nextReminderDate(for contact: Contact, rule: BirthdayReminderRule) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = BirthdayValue(rawValue: birthdayValue),
            let month = birthday.month,
            let day = birthday.day,
            let monthDay = reminderMonthDay(month: month, day: day, daysBeforeBirthday: rule.daysBeforeBirthday)
        else {
            return nil
        }

        let components = DateComponents(month: monthDay.month, day: monthDay.day, hour: rule.hour, minute: rule.minute)
        return Self.calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }

    private func reminderMonthDay(month: Int, day: Int, daysBeforeBirthday: Int) -> DateComponents? {
        guard
            let fixedDate = Self.calendar.date(from: DateComponents(year: 2001, month: month, day: day)),
            let shiftedDate = Self.calendar.date(byAdding: .day, value: -daysBeforeBirthday, to: fixedDate)
        else {
            return nil
        }
        return Self.calendar.dateComponents([.month, .day], from: shiftedDate)
    }

    private static func ruleSort(_ lhs: BirthdayReminderRule, _ rhs: BirthdayReminderRule) -> Bool {
        if lhs.daysBeforeBirthday != rhs.daysBeforeBirthday {
            return lhs.daysBeforeBirthday < rhs.daysBeforeBirthday
        }
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }

    private static let reminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        return formatter
    }()

    private static let calendar = Calendar.current
}
