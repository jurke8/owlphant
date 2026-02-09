import SwiftUI
import UserNotifications

struct BirthdaysView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderRules: [BirthdayReminderRule] = []
    @State private var isPresentingAddReminder = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        if authorizationStatus == .notDetermined || authorizationStatus == .denied {
                            SectionCard {
                                Text("Notifications")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)

                                if authorizationStatus == .notDetermined {
                                    Text("Allow notifications to get birthday reminders.")
                                        .font(.system(.subheadline, design: .rounded))
                                        .foregroundStyle(AppTheme.muted)
                                    Button("Enable notifications") {
                                        Task {
                                            _ = await BirthdayReminderService.shared.requestAuthorization()
                                            await refreshStatusAndSync()
                                        }
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                } else {
                                    Text("Notifications are disabled. Enable them in system settings.")
                                        .font(.system(.footnote, design: .rounded))
                                        .foregroundStyle(AppTheme.muted)
                                }
                            }
                        }

                        SectionCard {
                            HStack {
                                Text("Birthday reminders")
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Button {
                                    isPresentingAddReminder = true
                                } label: {
                                    Label("Add reminder", systemImage: "plus")
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.tint)
                            }

                            Text("Applies to all contacts with a birthday.")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            ForEach(reminderRules) { rule in
                                HStack {
                                    Text(rule.title)
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Button {
                                        Task { await removeReminder(rule.id) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(AppTheme.muted)
                                    .accessibilityLabel("Remove reminder")
                                }
                                .padding(.vertical, 2)
                            }

                            if reminderRules.isEmpty {
                                Text("No reminders set.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }

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
                                            Text("Birthday: \(displayDate(contact.birthday))")
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
        .sheet(isPresented: $isPresentingAddReminder) {
            AddBirthdayReminderSheet(existingSignatures: Set(reminderRules.map(\.signature))) { newRule in
                Task {
                    await addReminder(newRule)
                }
            }
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
        authorizationStatus = await BirthdayReminderService.shared.authorizationStatus()
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, rules: reminderRules)
    }

    private func addReminder(_ rule: BirthdayReminderRule) async {
        reminderRules.append(rule)
        BirthdayReminderRule.saveToDefaults(reminderRules)
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, rules: reminderRules)
    }

    private func removeReminder(_ ruleID: UUID) async {
        reminderRules.removeAll { $0.id == ruleID }
        BirthdayReminderRule.saveToDefaults(reminderRules)
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, rules: reminderRules)
    }

    private func displayDate(_ value: String?) -> String {
        guard let value, let date = Self.isoFormatter.date(from: value) else { return "-" }
        return Self.displayFormatter.string(from: date)
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

private struct AddBirthdayReminderSheet: View {
    let existingSignatures: Set<String>
    let onSave: (BirthdayReminderRule) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var daysBeforeBirthday = 0
    @State private var reminderTime = AddBirthdayReminderSheet.defaultTime
    @State private var duplicateMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    Stepper(value: $daysBeforeBirthday, in: 0 ... 365) {
                        if daysBeforeBirthday == 0 {
                            Text("On birthday")
                        } else if daysBeforeBirthday == 1 {
                            Text("1 day before")
                        } else {
                            Text("\(daysBeforeBirthday) days before")
                        }
                    }

                    DatePicker(
                        "Time",
                        selection: $reminderTime,
                        displayedComponents: [.hourAndMinute]
                    )
                }

                if let duplicateMessage {
                    Section {
                        Text(duplicateMessage)
                            .font(.system(.footnote, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add reminder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReminder()
                    }
                }
            }
        }
    }

    private func saveReminder() {
        let components = Self.calendar.dateComponents([.hour, .minute], from: reminderTime)
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0
        let newRule = BirthdayReminderRule(id: UUID(), daysBeforeBirthday: daysBeforeBirthday, hour: hour, minute: minute)

        if existingSignatures.contains(newRule.signature) {
            duplicateMessage = "This reminder already exists."
            return
        }

        onSave(newRule)
        dismiss()
    }

    private static let calendar = Calendar.current
    private static let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
}
