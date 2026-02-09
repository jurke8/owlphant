import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderRules: [BirthdayReminderRule] = []
    @State private var isPresentingAddReminder = false
    @Environment(\.scenePhase) private var scenePhase

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text("Appearance")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text("Choose how Owlphant looks across the app.")
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            VStack(spacing: 8) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    appearanceModeRow(mode)
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

                            Text("Manage reminders for all contacts with a birthday.")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            notificationStatusRow

                            if authorizationStatus == .notDetermined {
                                Button("Enable notifications") {
                                    Task {
                                        _ = await BirthdayReminderService.shared.requestAuthorization()
                                        await refreshStatusAndSync()
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }

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
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(AppTheme.surfaceAlt.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                            }

                            if reminderRules.isEmpty {
                                Text("No reminders set yet.")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(AppTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.surfaceAlt.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(AppTheme.stroke, lineWidth: 1)
                                    )
                            }
                        }

                        SectionCard {
                            Text("Encryption enabled. Data stays local-first.")
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await refreshStatusAndSync()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task { await refreshStatusAndSync() }
        }
        .onChange(of: viewModel.contacts) { _, _ in
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

    private func appearanceModeRow(_ mode: AppearanceMode) -> some View {
        Button {
            appearanceModeRawValue = mode.rawValue
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AppTheme.text)

                    Text(mode.subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                Image(systemName: appearanceMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appearanceMode == mode ? AppTheme.tint : AppTheme.stroke)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceAlt.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(appearanceMode == mode ? AppTheme.tint.opacity(0.55) : AppTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var notificationStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: notificationStatusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(notificationStatusColor)
            Text(notificationStatusText)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var notificationStatusText: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are enabled."
        case .denied:
            return "Notifications are disabled. Enable them in system settings."
        case .notDetermined:
            return "Notifications are not enabled yet."
        @unknown default:
            return "Notification status unavailable."
        }
    }

    private var notificationStatusIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "bell.badge"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var notificationStatusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return AppTheme.tint
        @unknown default:
            return AppTheme.muted
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

    private static func ruleSort(_ lhs: BirthdayReminderRule, _ rhs: BirthdayReminderRule) -> Bool {
        if lhs.daysBeforeBirthday != rhs.daysBeforeBirthday {
            return lhs.daysBeforeBirthday < rhs.daysBeforeBirthday
        }
        if lhs.hour != rhs.hour {
            return lhs.hour < rhs.hour
        }
        return lhs.minute < rhs.minute
    }
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
