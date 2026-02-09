import SwiftUI
import UserNotifications

struct RemindersView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @AppStorage(BirthdayReminderTiming.storageKey) private var reminderTimingRawValue = BirthdayReminderTiming.defaultValue.rawValue
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text("Reminders")
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundStyle(AppTheme.text)
                            Text("Never miss birthdays with local notifications.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }

                        SectionCard {
                            Text("Notifications")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(statusDescription)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            if authorizationStatus == .notDetermined {
                                Button("Enable notifications") {
                                    Task {
                                        _ = await BirthdayReminderService.shared.requestAuthorization()
                                        await refreshStatusAndSync()
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            } else if authorizationStatus == .denied {
                                Text("Notifications are disabled. Enable them in system settings.")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            }
                        }

                        SectionCard {
                            Text("Birthday schedule")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Picker("Reminder timing", selection: $reminderTimingRawValue) {
                                ForEach(BirthdayReminderTiming.allCases) { timing in
                                    Text(timing.title).tag(timing.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .appInputChrome()

                            Text("Applies to all contacts with a birthday.")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }

                        SectionCard {
                            Text("Tracked birthdays")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text("\(birthdayContacts.count) contacts")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            if birthdayContacts.isEmpty {
                                Text("Add birthdays in contacts to start receiving reminders.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                            } else {
                                ForEach(birthdayContacts.prefix(8)) { contact in
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
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await refreshStatusAndSync()
        }
        .onChange(of: reminderTimingRawValue) { _, _ in
            Task {
                await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, timing: selectedTiming)
            }
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshStatusAndSync() }
        }
    }

    private var selectedTiming: BirthdayReminderTiming {
        BirthdayReminderTiming.fromStored(reminderTimingRawValue)
    }

    private var birthdayContacts: [Contact] {
        viewModel.contacts
            .filter { contact in
                guard let birthday = contact.birthday?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
                return !birthday.isEmpty
            }
            .sorted { $0.displayName < $1.displayName }
    }

    private var statusDescription: String {
        switch authorizationStatus {
        case .ephemeral:
            return "Birthday reminders are enabled."
        case .authorized, .provisional:
            return "Birthday reminders are enabled."
        case .notDetermined:
            return "Allow notifications to get birthday reminders."
        case .denied:
            return "Notifications are off. Enable them in Settings."
        @unknown default:
            return "Notification status is unavailable."
        }
    }

    private func refreshStatusAndSync() async {
        authorizationStatus = await BirthdayReminderService.shared.authorizationStatus()
        await BirthdayReminderService.shared.syncBirthdays(for: viewModel.contacts, timing: selectedTiming)
    }

    private func displayDate(_ value: String?) -> String {
        guard let value, let date = Self.isoFormatter.date(from: value) else { return "-" }
        return Self.displayFormatter.string(from: date)
    }

    private func nextReminderLabel(for contact: Contact) -> String {
        guard let date = nextReminderDate(for: contact) else { return "Next: -" }
        return "Next: \(Self.reminderFormatter.string(from: date))"
    }

    private func nextReminderDate(for contact: Contact) -> Date? {
        guard
            let birthdayValue = contact.birthday,
            let birthday = Self.isoFormatter.date(from: birthdayValue),
            let monthDay = reminderMonthDay(for: birthday, timing: selectedTiming)
        else {
            return nil
        }

        let hour = selectedTiming == .dayBeforeAt2PM ? 14 : 9
        let components = DateComponents(month: monthDay.month, day: monthDay.day, hour: hour, minute: 0)
        return Self.calendar.nextDate(after: Date(), matching: components, matchingPolicy: .nextTime)
    }

    private func reminderMonthDay(for birthday: Date, timing: BirthdayReminderTiming) -> DateComponents? {
        let source = Self.calendar.dateComponents([.month, .day], from: birthday)
        guard let month = source.month, let day = source.day else { return nil }

        switch timing {
        case .onBirthdayAt9AM:
            return DateComponents(month: month, day: day)
        case .dayBeforeAt9AM, .dayBeforeAt2PM:
            guard
                let fixedDate = Self.calendar.date(from: DateComponents(year: 2001, month: month, day: day)),
                let dayBefore = Self.calendar.date(byAdding: .day, value: -1, to: fixedDate)
            else {
                return nil
            }
            return Self.calendar.dateComponents([.month, .day], from: dayBefore)
        }
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
