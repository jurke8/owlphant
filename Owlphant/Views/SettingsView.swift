import Contacts
import ContactsUI
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.defaultValue.rawValue
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderRules: [BirthdayReminderRule] = []
    @State private var isPresentingAddReminder = false
    @State private var isPresentingAddressBookPicker = false
    @Environment(\.scenePhase) private var scenePhase

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .defaultValue
    }

    var body: some View {
        NavigationStack {
            ScreenBackground {
                ScrollView {
                    VStack(spacing: 18) {
                        SectionCard {
                            Text(L10n.tr("settings.appearance.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            VStack(spacing: 8) {
                                ForEach(AppearanceMode.allCases) { mode in
                                    appearanceModeRow(mode)
                                }
                            }
                        }

                        SectionCard {
                            Text(L10n.tr("settings.language.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            VStack(spacing: 8) {
                                ForEach(AppLanguage.allCases) { language in
                                    languageRow(language)
                                }
                            }
                        }

                        SectionCard {
                            HStack {
                                Text(L10n.tr("settings.reminders.title"))
                                    .font(.system(.headline, design: .rounded).weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Button {
                                    isPresentingAddReminder = true
                                } label: {
                                    Label(L10n.tr("settings.reminders.add"), systemImage: "plus")
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.tint)
                            }

                            Text(L10n.tr("settings.reminders.subtitle"))
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            notificationStatusRow

                            if authorizationStatus == .notDetermined {
                                Button(L10n.tr("settings.notifications.enable")) {
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
                                    .accessibilityLabel(L10n.tr("settings.reminders.remove"))
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
                                Text(L10n.tr("settings.reminders.empty"))
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
                            Text(L10n.tr("settings.import.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(L10n.tr("settings.import.subtitle"))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            Button(L10n.tr("contacts.import.button")) {
                                Task {
                                    if await viewModel.requestAddressBookAccess() {
                                        isPresentingAddressBookPicker = true
                                    }
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Divider()

                            Button(L10n.tr("settings.import.meetings.button")) {
                                Task {
                                    await viewModel.importUpcomingMeetingsFromCalendar()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }

                        SectionCard {
                            Text(L10n.tr("settings.encryption.note"))
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppTheme.muted)
                        }

                        Spacer(minLength: 10)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(L10n.tr("tab.settings"))
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
        .sheet(isPresented: $isPresentingAddressBookPicker) {
            AddressBookContactPicker(
                onCancel: { isPresentingAddressBookPicker = false },
                onSelect: { contacts in
                    isPresentingAddressBookPicker = false
                    Task {
                        await viewModel.importFromAddressBook(contacts)
                    }
                }
            )
        }
        .alert(L10n.tr("common.notice"), isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
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

    private func languageRow(_ language: AppLanguage) -> some View {
        Button {
            appLanguageRawValue = language.rawValue
        } label: {
            HStack(spacing: 12) {
                Text(language.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Spacer()

                Image(systemName: appLanguage == language ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appLanguage == language ? AppTheme.tint : AppTheme.stroke)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceAlt.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(appLanguage == language ? AppTheme.tint.opacity(0.55) : AppTheme.stroke, lineWidth: 1)
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
            return L10n.tr("settings.notifications.enabled")
        case .denied:
            return L10n.tr("settings.notifications.disabled")
        case .notDetermined:
            return L10n.tr("settings.notifications.notEnabled")
        @unknown default:
            return L10n.tr("settings.notifications.unavailable")
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
        await BirthdayReminderService.shared.syncAllReminders(for: viewModel.contacts, rules: reminderRules)
    }

    private func addReminder(_ rule: BirthdayReminderRule) async {
        reminderRules.append(rule)
        BirthdayReminderRule.saveToDefaults(reminderRules)
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncAllReminders(for: viewModel.contacts, rules: reminderRules)
    }

    private func removeReminder(_ ruleID: UUID) async {
        reminderRules.removeAll { $0.id == ruleID }
        BirthdayReminderRule.saveToDefaults(reminderRules)
        reminderRules = BirthdayReminderRule.loadFromDefaults().sorted(by: Self.ruleSort)
        await BirthdayReminderService.shared.syncAllReminders(for: viewModel.contacts, rules: reminderRules)
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

private struct AddressBookContactPicker: UIViewControllerRepresentable {
    let onCancel: () -> Void
    let onSelect: ([CNContact]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCancel: onCancel, onSelect: onSelect)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let onCancel: () -> Void
        private let onSelect: ([CNContact]) -> Void

        init(onCancel: @escaping () -> Void, onSelect: @escaping ([CNContact]) -> Void) {
            self.onCancel = onCancel
            self.onSelect = onSelect
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            onCancel()
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect([contact])
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            onSelect(contacts)
        }
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
                Section(L10n.tr("settings.addReminder.when")) {
                    Stepper(value: $daysBeforeBirthday, in: 0 ... 365) {
                        if daysBeforeBirthday == 0 {
                            Text(L10n.tr("settings.addReminder.onBirthday"))
                        } else if daysBeforeBirthday == 1 {
                            Text(L10n.tr("settings.addReminder.oneDayBefore"))
                        } else {
                            Text(L10n.format("settings.addReminder.daysBefore", daysBeforeBirthday))
                        }
                    }

                    DatePicker(
                        L10n.tr("settings.addReminder.time"),
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
            .navigationTitle(L10n.tr("settings.addReminder.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save")) {
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
            duplicateMessage = L10n.tr("settings.addReminder.duplicate")
            return
        }

        onSave(newRule)
        dismiss()
    }

    private static let calendar = Calendar.current
    private static let defaultTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
}
