import Contacts
import ContactsUI
import LocalAuthentication
import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct SettingsView: View {
    @ObservedObject var viewModel: ContactsViewModel
    @EnvironmentObject var appLockService: AppLockService
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRawValue: String = AppearanceMode.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue: String = AppLanguage.defaultValue.rawValue
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var reminderRules: [BirthdayReminderRule] = []
    @State private var isPresentingAddReminder = false
    @State private var isPresentingAddressBookPicker = false
    @State private var isPresentingBackupExporter = false
    @State private var isPresentingBackupImporter = false
    @State private var isPresentingExportPassphraseSheet = false
    @State private var isPresentingImportPassphraseSheet = false
    @State private var exportPassphrase = ""
    @State private var exportPassphraseConfirmation = ""
    @State private var importPassphrase = ""
    @State private var pendingBackupDocument: BackupFileDocument?
    @State private var selectedBackupURL: URL?
    @State private var backupStatusMessage: String?
    @State private var appLockAuthFailed = false
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
                            Text(L10n.tr("settings.security.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            appLockToggleRow

                            appLockStatusRow
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
                            Text(L10n.tr("settings.backup.title"))
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(AppTheme.text)

                            Text(L10n.tr("settings.backup.subtitle"))
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(AppTheme.muted)

                            Button(L10n.tr("settings.backup.export.button")) {
                                exportPassphrase = ""
                                exportPassphraseConfirmation = ""
                                isPresentingExportPassphraseSheet = true
                            }
                            .buttonStyle(PrimaryButtonStyle())

                            Divider()

                            Button(L10n.tr("settings.backup.import.button")) {
                                isPresentingBackupImporter = true
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
        .sheet(isPresented: $isPresentingExportPassphraseSheet) {
            backupPassphraseSheet(
                title: L10n.tr("settings.backup.export.passphrase.title"),
                subtitle: L10n.tr("settings.backup.export.passphrase.subtitle"),
                passphrase: $exportPassphrase,
                confirmPassphrase: $exportPassphraseConfirmation,
                actionLabel: L10n.tr("settings.backup.export.passphrase.action"),
                actionRole: nil,
                onConfirm: startBackupExport
            )
        }
        .sheet(isPresented: $isPresentingImportPassphraseSheet) {
            backupPassphraseSheet(
                title: L10n.tr("settings.backup.import.passphrase.title"),
                subtitle: L10n.tr("settings.backup.import.passphrase.subtitle"),
                passphrase: $importPassphrase,
                confirmPassphrase: .constant(""),
                actionLabel: L10n.tr("settings.backup.import.passphrase.action"),
                actionRole: .destructive,
                onConfirm: startBackupImport
            )
        }
        .fileExporter(
            isPresented: $isPresentingBackupExporter,
            document: pendingBackupDocument,
            contentType: .owlphantBackup,
            defaultFilename: backupFilename
        ) { result in
            switch result {
            case .success:
                backupStatusMessage = L10n.tr("settings.backup.export.success")
            case .failure:
                viewModel.errorMessage = L10n.tr("error.backup.export")
            }
        }
        .fileImporter(
            isPresented: $isPresentingBackupImporter,
            allowedContentTypes: [.owlphantBackup, .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    viewModel.errorMessage = L10n.tr("error.backup.import.invalidFile")
                    return
                }
                selectedBackupURL = url
                importPassphrase = ""
                isPresentingImportPassphraseSheet = true
            case .failure:
                viewModel.errorMessage = L10n.tr("error.backup.import.invalidFile")
            }
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
        .alert(L10n.tr("common.notice"), isPresented: Binding(
            get: { backupStatusMessage != nil },
            set: { if !$0 { backupStatusMessage = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) {
                backupStatusMessage = nil
            }
        } message: {
            Text(backupStatusMessage ?? "")
        }
        .alert(L10n.tr("common.notice"), isPresented: $appLockAuthFailed) {
            Button(L10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(L10n.tr("settings.security.authFailed"))
        }
    }

    private var backupFilename: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return "owlphant-backup-\(formatter.string(from: Date())).owlbackup"
    }

    private func startBackupExport() {
        let trimmedPassphrase = exportPassphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirmation = exportPassphraseConfirmation.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedPassphrase.isEmpty else {
            viewModel.errorMessage = L10n.tr("error.backup.passphrase.empty")
            return
        }

        guard trimmedPassphrase == trimmedConfirmation else {
            viewModel.errorMessage = L10n.tr("error.backup.passphrase.mismatch")
            return
        }

        do {
            let backupData = try viewModel.exportEncryptedBackup(passphrase: trimmedPassphrase)
            pendingBackupDocument = BackupFileDocument(data: backupData)
            isPresentingExportPassphraseSheet = false
            isPresentingBackupExporter = true
        } catch {
            viewModel.errorMessage = L10n.tr("error.backup.export")
        }
    }

    private func startBackupImport() {
        guard let backupURL = selectedBackupURL else {
            viewModel.errorMessage = L10n.tr("error.backup.import.invalidFile")
            return
        }

        let trimmedPassphrase = importPassphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassphrase.isEmpty else {
            viewModel.errorMessage = L10n.tr("error.backup.passphrase.empty")
            return
        }

        isPresentingImportPassphraseSheet = false

        Task {
            do {
                let backupData = try readBackupData(from: backupURL)
                await viewModel.importEncryptedBackup(data: backupData, passphrase: trimmedPassphrase)
                if viewModel.errorMessage == nil {
                    backupStatusMessage = L10n.format("settings.backup.import.success", viewModel.contacts.count)
                }
            } catch {
                viewModel.errorMessage = L10n.tr("error.backup.import.invalidFile")
            }
            selectedBackupURL = nil
        }
    }

    private func readBackupData(from url: URL) throws -> Data {
        let hasSecurityAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try Data(contentsOf: url)
    }

    private func backupPassphraseSheet(
        title: String,
        subtitle: String,
        passphrase: Binding<String>,
        confirmPassphrase: Binding<String>,
        actionLabel: String,
        actionRole: ButtonRole?,
        onConfirm: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            ScreenBackground {
                VStack(spacing: 14) {
                    SectionCard {
                        Text(title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(AppTheme.muted)

                        SecureField(L10n.tr("settings.backup.passphrase"), text: passphrase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .appInputChrome()

                        if !confirmPassphrase.wrappedValue.isEmpty || actionRole == nil {
                            SecureField(L10n.tr("settings.backup.passphrase.confirm"), text: confirmPassphrase)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .appInputChrome()
                        }

                        Button(actionLabel, role: actionRole) {
                            onConfirm()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    Button(L10n.tr("common.cancel")) {
                        isPresentingExportPassphraseSheet = false
                        isPresentingImportPassphraseSheet = false
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - App Lock

    private var appLockToggleLabel: String {
        switch appLockService.biometryType {
        case .touchID:
            return L10n.tr("settings.security.appLock.touchId")
        case .opticID:
            return L10n.tr("settings.security.appLock.opticId")
        default:
            return L10n.tr("settings.security.appLock")
        }
    }

    private var appLockToggleRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(appLockToggleLabel)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(AppTheme.text)

                Text(L10n.tr("settings.security.appLock.subtitle"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { appLockService.isEnabled },
                set: { newValue in
                    if newValue {
                        Task {
                            let success = await appLockService.verifyCanAuthenticate()
                            if success {
                                appLockService.isEnabled = true
                            } else {
                                appLockService.isEnabled = false
                                appLockAuthFailed = true
                            }
                        }
                    } else {
                        appLockService.isEnabled = false
                    }
                }
            ))
            .labelsHidden()
            .tint(AppTheme.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceAlt.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(appLockService.isEnabled ? AppTheme.tint.opacity(0.55) : AppTheme.stroke, lineWidth: 1)
        )
    }

    private var appLockStatusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: appLockService.isBiometryAvailable ? appLockService.biometryIconName : "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(appLockService.isBiometryAvailable ? AppTheme.tint : AppTheme.muted)
            Text(appLockService.isBiometryAvailable
                 ? L10n.tr("settings.security.biometry.available")
                 : L10n.tr("settings.security.biometry.unavailable"))
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

    // MARK: - Appearance

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

private struct BackupFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.owlphantBackup, .data] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private extension UTType {
    static let owlphantBackup = UTType(exportedAs: "com.owlphant.backup")
}
