import SwiftUI

struct BirthdaysView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var reminderRules: [BirthdayReminderRule] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text("Upcoming birthdays")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text("\(upcomingBirthdayContacts.count) contacts")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            if upcomingBirthdayContacts.isEmpty {
                                Text("Add birthdays in contacts to start receiving reminders.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                ForEach(upcomingBirthdayContacts.prefix(8)) { contact in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(contact.displayName)
                                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text("Birthday: \(birthdayDetails(for: contact))")
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

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Birthdays")
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
                guard let birthday = contact.birthday?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
                return !birthday.isEmpty
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
        await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, rules: reminderRules)
    }

    private func displayDate(_ value: String?) -> String {
        guard let value, let date = Self.isoFormatter.date(from: value) else { return "-" }
        return Self.displayFormatter.string(from: date)
    }

    private func birthdayDetails(for contact: Contact) -> String {
        let dateText = displayDate(contact.birthday)
        guard let upcomingAge = upcomingAge(for: contact) else {
            return dateText
        }
        return "\(dateText) (\(upcomingAge))"
    }

    private func upcomingAge(for contact: Contact) -> Int? {
        guard
            let value = contact.birthday,
            let birthday = Self.isoFormatter.date(from: value),
            let nextBirthday = nextBirthdayDate(for: contact)
        else {
            return nil
        }

        let birthYear = Self.calendar.component(.year, from: birthday)
        let nextBirthdayYear = Self.calendar.component(.year, from: nextBirthday)
        let age = nextBirthdayYear - birthYear
        return age > 0 ? age : nil
    }

    private func nextReminderLabel(for contact: Contact) -> String {
        let next = reminderRules
            .compactMap { nextReminderDate(for: contact, rule: $0) }
            .min()
        guard let date = next else { return "Next: -" }
        return "Next: \(Self.reminderFormatter.string(from: date))"
    }

    private func nextBirthdayDate(for contact: Contact) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = Self.isoFormatter.date(from: birthdayValue)
        else {
            return nil
        }

        let source = Self.calendar.dateComponents([.month, .day], from: birthday)
        guard let month = source.month, let day = source.day else { return nil }
        return Self.calendar.nextDate(
            after: Date(),
            matching: DateComponents(month: month, day: day, hour: 0, minute: 0),
            matchingPolicy: .nextTime
        )
    }

    private func nextReminderDate(for contact: Contact, rule: BirthdayReminderRule) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = Self.isoFormatter.date(from: birthdayValue),
            let monthDay = reminderMonthDay(for: birthday, daysBeforeBirthday: rule.daysBeforeBirthday)
        else {
            return nil
        }

        let components = DateComponents(month: monthDay.month, day: monthDay.day, hour: rule.hour, minute: rule.minute)
        return Self.calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }

    private func reminderMonthDay(for birthday: Date, daysBeforeBirthday: Int) -> DateComponents? {
        let source = Self.calendar.dateComponents([.month, .day], from: birthday)
        guard let month = source.month, let day = source.day else { return nil }
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

    private static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM d")
        return formatter
    }()

    private static let reminderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d, h:mm a")
        return formatter
    }()

    private static let calendar = Calendar.current
}
