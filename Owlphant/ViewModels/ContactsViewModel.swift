import Combine
import Contacts
import EventKit
import Foundation

enum ContactSortField: String, CaseIterable {
    case recent
    case name
    case birthdate

    var localizedTitle: String {
        switch self {
        case .recent:
            return L10n.tr("contacts.sort.field.recent")
        case .name:
            return L10n.tr("contacts.sort.field.name")
        case .birthdate:
            return L10n.tr("contacts.sort.field.birthdate")
        }
    }
}

enum ContactSortDirection: String, CaseIterable {
    case ascending
    case descending

    var localizedTitle: String {
        switch self {
        case .ascending:
            return L10n.tr("contacts.sort.direction.ascending")
        case .descending:
            return L10n.tr("contacts.sort.direction.descending")
        }
    }
}

struct ContactFormState {
    var firstName = ""
    var lastName = ""
    var nickname = ""
    var birthday = "1990-01"
    var photoData: Data?
    var placeOfBirth = ""
    var placeOfLiving = ""
    var company = ""
    var workPosition = ""
    var phones = ""
    var emails = ""
    var facebook = ""
    var linkedin = ""
    var instagram = ""
    var x = ""
    var notes = ""
    var tags = ""
    var coffeeReminderAt: TimeInterval?
    var stayInTouchEveryDays: Int?
    var interactions: [ContactInteraction] = []
    var interactionDraftDate = Date()
    var interactionDraftNote = ""
    var editingInteractionId: UUID?

    var relationships: [ContactRelationship] = []
    var relationshipDraftTargetId: UUID?
    var relationshipDraftType: RelationshipType = .friend
    var relationshipDraftIndex: Int?
}

@MainActor
final class ContactsViewModel: ObservableObject {
    @Published var isReady = false
    @Published var contacts: [Contact] = []
    @Published var query = ""
    @Published var sortField: ContactSortField = .recent
    @Published var sortDirection: ContactSortDirection = .descending
    @Published var isPresentingForm = false
    @Published var form = ContactFormState()
    @Published var selectedContactId: UUID?
    @Published var errorMessage: String?
    @Published var upcomingMeetings: [UpcomingMeeting] = []

    private let store = EncryptedContactsStore()
    private let backupService = EncryptedBackupService()
    private let reminderService = BirthdayReminderService.shared
    private let eventStore = EKEventStore()

    private enum SocialValidationError: Error {
        case invalidURL
        case invalidEmail
    }

    var filteredContacts: [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [Contact]
        if trimmed.isEmpty {
            filtered = contacts
        } else {
            filtered = contacts.filter { contact in
                let channelText = [
                    contact.emails.joined(separator: " "),
                    contact.phones.joined(separator: " "),
                    (contact.facebook ?? []).joined(separator: " "),
                    (contact.linkedin ?? []).joined(separator: " "),
                    (contact.instagram ?? []).joined(separator: " "),
                    (contact.x ?? []).joined(separator: " "),
                ].joined(separator: " ")

                let haystack = [
                    contact.firstName,
                    contact.lastName,
                    contact.nickname ?? "",
                    contact.birthday ?? "",
                    contact.placeOfBirth ?? "",
                    contact.placeOfLiving ?? "",
                    contact.company ?? "",
                    contact.workPosition ?? "",
                    channelText,
                    contact.notes ?? "",
                    contact.interactions.map(\.note).joined(separator: " "),
                    contact.tags.joined(separator: " "),
                ].joined(separator: " ").lowercased()
                return haystack.contains(trimmed)
            }
        }

        return filtered.sorted(by: sortComparator)
    }

    private func sortComparator(_ lhs: Contact, _ rhs: Contact) -> Bool {
        switch sortField {
        case .recent:
            return compareRecent(lhs, rhs)
        case .name:
            return compareName(lhs, rhs)
        case .birthdate:
            return compareBirthdate(lhs, rhs)
        }
    }

    private func compareRecent(_ lhs: Contact, _ rhs: Contact) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            if sortDirection == .ascending {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhs.updatedAt > rhs.updatedAt
        }
        return tieBreak(lhs, rhs)
    }

    private func compareName(_ lhs: Contact, _ rhs: Contact) -> Bool {
        let lhsName = normalizedName(lhs)
        let rhsName = normalizedName(rhs)

        if lhsName != rhsName {
            if sortDirection == .ascending {
                return lhsName < rhsName
            }
            return lhsName > rhsName
        }

        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func compareBirthdate(_ lhs: Contact, _ rhs: Contact) -> Bool {
        let lhsBirthdate = birthdateSortKey(for: lhs)
        let rhsBirthdate = birthdateSortKey(for: rhs)

        switch (lhsBirthdate, rhsBirthdate) {
        case let (.some(lhsValue), .some(rhsValue)):
            if lhsValue != rhsValue {
                if sortDirection == .ascending {
                    return lhsValue < rhsValue
                }
                return lhsValue > rhsValue
            }
            return tieBreak(lhs, rhs)
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return tieBreak(lhs, rhs)
        }
    }

    private func birthdateSortKey(for contact: Contact) -> (Int, Int, Int)? {
        guard
            let birthday = contact.birthday,
            let value = BirthdayValue(rawValue: birthday)
        else {
            return nil
        }

        return (value.year, value.month ?? 13, value.day ?? 32)
    }

    private func normalizedName(_ contact: Contact) -> String {
        contact.displayName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tieBreak(_ lhs: Contact, _ rhs: Contact) -> Bool {
        let lhsName = normalizedName(lhs)
        let rhsName = normalizedName(rhs)

        if lhsName != rhsName {
            return lhsName < rhsName
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    func bootstrap() async {
        do {
            var localContacts = try await store.loadContacts()

            if localContacts.isEmpty {
                localContacts = try await store.ensureSeedDataIfEmpty(seedContacts: Contact.sampleSeed)
            }

            contacts = localContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncReminders()
            refreshUpcomingMeetingsIfAuthorized()
            isReady = true
        } catch {
            errorMessage = L10n.tr("error.storage.load")
            isReady = true
        }
    }

    func startCreate() {
        selectedContactId = nil
        form = ContactFormState()
        isPresentingForm = true
    }

    func startEdit(_ contact: Contact) {
        selectedContactId = contact.id
        form.firstName = contact.firstName
        form.lastName = contact.lastName
        form.nickname = contact.nickname ?? ""
        form.birthday = contact.birthday ?? "1990-01"
        if let encodedPhoto = contact.photoDataBase64 {
            form.photoData = Foundation.Data(base64Encoded: encodedPhoto)
        } else {
            form.photoData = nil
        }
        form.placeOfBirth = contact.placeOfBirth ?? ""
        form.placeOfLiving = contact.placeOfLiving ?? ""
        form.company = contact.company ?? ""
        form.workPosition = contact.workPosition ?? ""
        form.phones = contact.phones.joined(separator: ", ")
        form.emails = contact.emails.joined(separator: ", ")
        form.facebook = (contact.facebook ?? []).joined(separator: ", ")
        form.linkedin = (contact.linkedin ?? []).joined(separator: ", ")
        form.instagram = (contact.instagram ?? []).joined(separator: ", ")
        form.x = (contact.x ?? []).joined(separator: ", ")
        form.notes = contact.notes ?? ""
        form.tags = contact.tags.joined(separator: ", ")
        form.interactions = contact.interactions.sorted { $0.date > $1.date }
        form.interactionDraftDate = Date()
        form.interactionDraftNote = ""
        form.editingInteractionId = nil
        form.relationships = contact.relationships
        form.coffeeReminderAt = contact.coffeeReminderAt
        form.stayInTouchEveryDays = contact.stayInTouchEveryDays
        form.relationshipDraftTargetId = nil
        form.relationshipDraftType = .friend
        form.relationshipDraftIndex = nil
        isPresentingForm = true
    }

    func cancelForm() {
        selectedContactId = nil
        form = ContactFormState()
        isPresentingForm = false
    }

    func save() async {
        let first = form.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = form.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = form.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !first.isEmpty || !last.isEmpty || !nickname.isEmpty else {
            errorMessage = L10n.tr("error.contact.missingName")
            return
        }

        let facebookLinks: [String]?
        let linkedinLinks: [String]?
        let instagramLinks: [String]?
        let xLinks: [String]?
        let emails: [String]

        do {
            emails = try validatedEmails(from: form.emails)
            facebookLinks = try validatedSocialLinks(from: form.facebook, platform: .facebook)
            linkedinLinks = try validatedSocialLinks(from: form.linkedin, platform: .linkedin)
            instagramLinks = try validatedSocialLinks(from: form.instagram, platform: .instagram)
            xLinks = try validatedSocialLinks(from: form.x, platform: .x)
        } catch {
            if let error = error as? SocialValidationError {
                switch error {
                case .invalidURL:
                    errorMessage = L10n.tr("error.contact.social.invalid")
                case .invalidEmail:
                    errorMessage = L10n.tr("error.contact.email.invalid")
                }
            } else {
                errorMessage = L10n.tr("error.contact.save")
            }
            return
        }

        let now = Date().timeIntervalSince1970
        let id = selectedContactId ?? UUID()
        var updatedContacts = contacts

        let contact = Contact(
            id: id,
            firstName: first,
            lastName: last,
            nickname: normalizedOptional(form.nickname),
            birthday: normalizedOptional(form.birthday),
            photoDataBase64: form.photoData?.base64EncodedString(),
            placeOfBirth: normalizedOptional(form.placeOfBirth),
            placeOfLiving: normalizedOptional(form.placeOfLiving),
            company: normalizedOptional(form.company),
            workPosition: normalizedOptional(form.workPosition),
            phones: parseCSV(form.phones),
            emails: emails,
            facebook: facebookLinks,
            linkedin: linkedinLinks,
            instagram: instagramLinks,
            x: xLinks,
            notes: normalizedOptional(form.notes),
            tags: parseCSV(form.tags),
            relationships: form.relationships,
            interactions: normalizedInteractions(form.interactions),
            coffeeReminderAt: normalizedFutureTimestamp(form.coffeeReminderAt),
            stayInTouchEveryDays: normalizedReminderInterval(form.stayInTouchEveryDays),
            updatedAt: now
        )

        if let idx = updatedContacts.firstIndex(where: { $0.id == id }) {
            updatedContacts[idx] = contact
        } else {
            updatedContacts.append(contact)
        }

        for rel in contact.relationships {
            guard let targetIndex = updatedContacts.firstIndex(where: { $0.id == rel.contactId }) else { continue }
            let reciprocal = ContactRelationship(contactId: id, type: rel.type.reciprocal)
            let already = updatedContacts[targetIndex].relationships.contains(where: {
                $0.contactId == reciprocal.contactId && $0.type == reciprocal.type
            })
            if !already {
                updatedContacts[targetIndex].relationships.append(reciprocal)
            }
        }

        do {
            try await store.saveContacts(updatedContacts)
            contacts = updatedContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncReminders()
            cancelForm()
        } catch {
            errorMessage = L10n.tr("error.contact.save")
        }
    }

    func delete(_ contact: Contact) async {
        var updatedContacts = contacts.filter { $0.id != contact.id }
        for idx in updatedContacts.indices {
            updatedContacts[idx].relationships.removeAll { $0.contactId == contact.id }
        }

        do {
            try await store.saveContacts(updatedContacts)
            contacts = updatedContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncReminders()
        } catch {
            errorMessage = L10n.tr("error.contact.delete")
        }
    }

    func addOrUpdateRelationshipDraft() {
        guard let targetId = form.relationshipDraftTargetId else { return }
        let relation = ContactRelationship(contactId: targetId, type: form.relationshipDraftType)

        if let draftIndex = form.relationshipDraftIndex {
            form.relationships[draftIndex] = relation
        } else {
            let duplicate = form.relationships.contains { $0.contactId == targetId && $0.type == form.relationshipDraftType }
            if duplicate { return }
            form.relationships.append(relation)
        }

        form.relationshipDraftTargetId = nil
        form.relationshipDraftType = .friend
        form.relationshipDraftIndex = nil
    }

    func removeRelationship(_ relationship: ContactRelationship) {
        form.relationships.removeAll { $0.id == relationship.id }
    }

    func editRelationship(_ relationship: ContactRelationship) {
        guard let idx = form.relationships.firstIndex(of: relationship) else { return }
        form.relationshipDraftTargetId = relationship.contactId
        form.relationshipDraftType = relationship.type
        form.relationshipDraftIndex = idx
    }

    func addOrUpdateInteractionDraft() {
        let note = form.interactionDraftNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }

        let timestamp = form.interactionDraftDate.timeIntervalSince1970

        if let editingId = form.editingInteractionId,
           let idx = form.interactions.firstIndex(where: { $0.id == editingId }) {
            form.interactions[idx].note = note
            form.interactions[idx].date = timestamp
        } else {
            form.interactions.append(
                ContactInteraction(id: UUID(), date: timestamp, note: note)
            )
        }

        form.interactions.sort { $0.date > $1.date }
        resetInteractionDraft()
    }

    func editInteraction(_ interaction: ContactInteraction) {
        form.editingInteractionId = interaction.id
        form.interactionDraftDate = Date(timeIntervalSince1970: interaction.date)
        form.interactionDraftNote = interaction.note
    }

    func removeInteraction(_ interaction: ContactInteraction) {
        form.interactions.removeAll { $0.id == interaction.id }

        if form.editingInteractionId == interaction.id {
            resetInteractionDraft()
        }
    }

    func resetInteractionDraft() {
        form.interactionDraftDate = Date()
        form.interactionDraftNote = ""
        form.editingInteractionId = nil
    }

    func relationshipTargetName(_ id: UUID) -> String {
        contacts.first(where: { $0.id == id })?.displayName ?? L10n.tr("contacts.unknown")
    }

    func requestAddressBookAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        switch status {
        case .authorized:
            return true
        case .limited:
            return true
        case .notDetermined:
            let store = CNContactStore()
            do {
                let granted: Bool = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
                    store.requestAccess(for: .contacts) { granted, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
                if !granted {
                    errorMessage = L10n.tr("error.contact.import.permission")
                }
                return granted
            } catch {
                errorMessage = L10n.tr("error.contact.import.permission")
                return false
            }
        case .denied, .restricted:
            errorMessage = L10n.tr("error.contact.import.permission")
            return false
        @unknown default:
            errorMessage = L10n.tr("error.contact.import.permission")
            return false
        }
    }

    func importFromAddressBook(_ importedContacts: [CNContact]) async {
        guard !importedContacts.isEmpty else { return }

        var updatedContacts = contacts
        let now = Date().timeIntervalSince1970

        for imported in importedContacts {
            let mapped = mappedContact(from: imported)
            guard mapped.hasAnyContent else { continue }

            if let matchIndex = bestMatchIndex(for: mapped, in: updatedContacts) {
                updatedContacts[matchIndex] = merge(existing: updatedContacts[matchIndex], with: mapped, now: now)
            } else {
                updatedContacts.append(newContact(from: mapped, now: now))
            }
        }

        guard updatedContacts != contacts else { return }

        do {
            try await store.saveContacts(updatedContacts)
            contacts = updatedContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncReminders()
        } catch {
            errorMessage = L10n.tr("error.contact.import.save")
        }
    }

    func importUpcomingMeetingsFromCalendar() async {
        do {
            let hasAccess = try await requestCalendarAccessIfNeeded()
            guard hasAccess else { return }
            upcomingMeetings = loadUpcomingMeetings()
        } catch {
            errorMessage = L10n.tr("error.calendar.import.load")
        }
    }

    func exportEncryptedBackup(passphrase: String) throws -> Data {
        let trimmedPassphrase = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassphrase.isEmpty else {
            throw EncryptedBackupServiceError.invalidFormat
        }
        return try backupService.exportBackupData(contacts: contacts, passphrase: trimmedPassphrase)
    }

    func importEncryptedBackup(data: Data, passphrase: String) async {
        let trimmedPassphrase = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPassphrase.isEmpty else {
            errorMessage = L10n.tr("error.backup.passphrase.empty")
            return
        }

        do {
            let importedContacts = try backupService.importContacts(from: data, passphrase: trimmedPassphrase)
            try await store.saveContacts(importedContacts)
            contacts = importedContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncReminders()
            refreshUpcomingMeetingsIfAuthorized()
        } catch EncryptedBackupServiceError.invalidFormat {
            errorMessage = L10n.tr("error.backup.import.invalidFile")
        } catch EncryptedBackupServiceError.decryptionFailed {
            errorMessage = L10n.tr("error.backup.import.decrypt")
        } catch {
            errorMessage = L10n.tr("error.backup.import.save")
        }
    }

    func refreshUpcomingMeetingsIfAuthorized() {
        guard hasCalendarReadAccess else { return }
        upcomingMeetings = loadUpcomingMeetings()
    }

    var availableRelationshipTargets: [Contact] {
        contacts.filter { $0.id != selectedContactId }.sorted { $0.displayName < $1.displayName }
    }

    var canSubmitForm: Bool {
        formValidationMessage == nil
    }

    var formValidationMessage: String? {
        if isNameMissing {
            return L10n.tr("error.contact.missingName")
        }
        if !hasValidEmails {
            return L10n.tr("error.contact.email.invalid")
        }
        if !hasValidSocialLinks {
            return L10n.tr("error.contact.social.invalid")
        }
        return nil
    }

    var canSubmitInteractionDraft: Bool {
        !form.interactionDraftNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func parseCSV(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseOptionalCSV(_ value: String) -> [String]? {
        let parsed = parseCSV(value)
        return parsed.isEmpty ? nil : parsed
    }

    private var isNameMissing: Bool {
        let first = form.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = form.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = form.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return first.isEmpty && last.isEmpty && nickname.isEmpty
    }

    private var hasValidEmails: Bool {
        let entries = parseCSV(form.emails)
        return entries.allSatisfy(isValidEmail)
    }

    private var hasValidSocialLinks: Bool {
        socialLinksAreValid(in: form.facebook, platform: .facebook)
            && socialLinksAreValid(in: form.linkedin, platform: .linkedin)
            && socialLinksAreValid(in: form.instagram, platform: .instagram)
            && socialLinksAreValid(in: form.x, platform: .x)
    }

    private func socialLinksAreValid(in value: String, platform: SocialPlatform) -> Bool {
        let entries = parseCSV(value)
        return entries.allSatisfy { SocialLinkValidator.normalize($0, platform: platform) != nil }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func validatedEmails(from value: String) throws -> [String] {
        let parsed = parseCSV(value)
        guard parsed.allSatisfy(isValidEmail) else {
            throw SocialValidationError.invalidEmail
        }
        return parsed
    }

    private func validatedSocialLinks(from value: String, platform: SocialPlatform) throws -> [String]? {
        let parsed = parseCSV(value)
        guard !parsed.isEmpty else { return nil }

        var normalized: [String] = []
        normalized.reserveCapacity(parsed.count)

        for entry in parsed {
            guard let urlString = SocialLinkValidator.normalize(entry, platform: platform) else {
                throw SocialValidationError.invalidURL
            }
            normalized.append(urlString)
        }

        return normalized
    }

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedInteractions(_ interactions: [ContactInteraction]) -> [ContactInteraction] {
        interactions
            .map { interaction in
                ContactInteraction(
                    id: interaction.id,
                    date: interaction.date,
                    note: interaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .filter { !$0.note.isEmpty }
            .sorted { $0.date > $1.date }
    }

    private func syncReminders() async {
        let rules = BirthdayReminderRule.loadFromDefaults()
        await reminderService.syncAllReminders(for: contacts, rules: rules)
    }

    private func normalizedFutureTimestamp(_ value: TimeInterval?) -> TimeInterval? {
        guard let value else { return nil }
        return value > Date().timeIntervalSince1970 ? value : nil
    }

    private func normalizedReminderInterval(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return min(value, 365)
    }

    private func mappedContact(from contact: CNContact) -> ImportedContact {
        let firstName = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastName = contact.familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname = normalizedOptional(contact.nickname)

        let emailValues = deduplicated(values: contact.emailAddresses.map { $0.value as String }, normalizer: normalizedEmail)
        let phoneValues = deduplicated(values: contact.phoneNumbers.map { $0.value.stringValue }, normalizer: normalizedPhone)

        return ImportedContact(
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            emails: emailValues,
            phones: phoneValues,
            normalizedEmails: Set(emailValues.compactMap { normalizedKey($0, using: normalizedEmail) }),
            normalizedPhones: Set(phoneValues.compactMap { normalizedKey($0, using: normalizedPhone) })
        )
    }

    private func bestMatchIndex(for imported: ImportedContact, in existingContacts: [Contact]) -> Int? {
        var bestIndex: Int?
        var bestScore = 0
        var bestUpdatedAt: TimeInterval = 0

        for idx in existingContacts.indices {
            let existing = existingContacts[idx]
            let existingEmails = Set(existing.emails.compactMap { normalizedKey($0, using: normalizedEmail) })
            let existingPhones = Set(existing.phones.compactMap { normalizedKey($0, using: normalizedPhone) })

            let emailOverlap = imported.normalizedEmails.intersection(existingEmails).count
            let phoneOverlap = imported.normalizedPhones.intersection(existingPhones).count
            let score = emailOverlap + phoneOverlap

            guard score > 0 else { continue }

            if score > bestScore || (score == bestScore && existing.updatedAt > bestUpdatedAt) {
                bestScore = score
                bestUpdatedAt = existing.updatedAt
                bestIndex = idx
            }
        }

        return bestIndex
    }

    private func merge(existing: Contact, with imported: ImportedContact, now: TimeInterval) -> Contact {
        let mergedEmails = mergedValues(existing.emails, imported.emails, normalizer: normalizedEmail)
        let mergedPhones = mergedValues(existing.phones, imported.phones, normalizer: normalizedPhone)

        let existingFirst = existing.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingLast = existing.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingNick = existing.nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return Contact(
            id: existing.id,
            firstName: existingFirst.isEmpty ? imported.firstName : existing.firstName,
            lastName: existingLast.isEmpty ? imported.lastName : existing.lastName,
            nickname: existingNick.isEmpty ? imported.nickname : existing.nickname,
            birthday: existing.birthday,
            photoDataBase64: existing.photoDataBase64,
            placeOfBirth: existing.placeOfBirth,
            placeOfLiving: existing.placeOfLiving,
            company: existing.company,
            workPosition: existing.workPosition,
            phones: mergedPhones,
            emails: mergedEmails,
            facebook: existing.facebook,
            linkedin: existing.linkedin,
            instagram: existing.instagram,
            x: existing.x,
            notes: existing.notes,
            tags: existing.tags,
            relationships: existing.relationships,
            interactions: existing.interactions,
            coffeeReminderAt: existing.coffeeReminderAt,
            stayInTouchEveryDays: existing.stayInTouchEveryDays,
            updatedAt: now
        )
    }

    private func newContact(from imported: ImportedContact, now: TimeInterval) -> Contact {
        Contact(
            id: UUID(),
            firstName: imported.firstName,
            lastName: imported.lastName,
            nickname: imported.nickname,
            birthday: nil,
            photoDataBase64: nil,
            placeOfBirth: nil,
            placeOfLiving: nil,
            company: nil,
            workPosition: nil,
            phones: imported.phones,
            emails: imported.emails,
            facebook: nil,
            linkedin: nil,
            instagram: nil,
            x: nil,
            notes: nil,
            tags: [],
            relationships: [],
            interactions: [],
            coffeeReminderAt: nil,
            stayInTouchEveryDays: nil,
            updatedAt: now
        )
    }

    private func mergedValues(_ existing: [String], _ incoming: [String], normalizer: (String) -> String) -> [String] {
        var result = existing
        var seen = Set(existing.compactMap { normalizedKey($0, using: normalizer) })

        for value in incoming {
            guard let key = normalizedKey(value, using: normalizer), !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value)
        }

        return result
    }

    private func deduplicated(values: [String], normalizer: (String) -> String) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []

        for value in values {
            guard let key = normalizedKey(value, using: normalizer), !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return result
    }

    private func normalizedKey(_ value: String, using normalizer: (String) -> String) -> String? {
        let normalized = normalizer(value)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizedEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedPhone(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let hasLeadingPlus = trimmed.first == "+"
        let digits = trimmed.filter { $0.isWholeNumber }
        guard !digits.isEmpty else { return "" }
        return hasLeadingPlus ? "+\(digits)" : digits
    }

    private func requestCalendarAccessIfNeeded() async throws -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess:
            return true
        case .writeOnly:
            errorMessage = L10n.tr("error.calendar.import.permission")
            return false
        case .notDetermined:
            let granted = try await eventStore.requestFullAccessToEvents()
            if !granted {
                errorMessage = L10n.tr("error.calendar.import.permission")
            }
            return granted
        case .denied, .restricted:
            errorMessage = L10n.tr("error.calendar.import.permission")
            return false
        @unknown default:
            errorMessage = L10n.tr("error.calendar.import.permission")
            return false
        }
    }

    private func loadUpcomingMeetings() -> [UpcomingMeeting] {
        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 30, to: now) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)

        return events
            .filter { !$0.isAllDay && $0.startDate >= now }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                UpcomingMeeting(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: meetingTitle(for: event),
                    startDate: event.startDate,
                    location: normalizedOptional(event.location ?? ""),
                    calendarName: normalizedOptional(event.calendar.title)
                )
            }
    }

    private func meetingTitle(for event: EKEvent) -> String {
        let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? L10n.tr("events.meetings.item.untitled") : title
    }

    private var hasCalendarReadAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess
    }
}

private struct ImportedContact {
    let firstName: String
    let lastName: String
    let nickname: String?
    let emails: [String]
    let phones: [String]
    let normalizedEmails: Set<String>
    let normalizedPhones: Set<String>

    var hasAnyContent: Bool {
        !firstName.isEmpty || !lastName.isEmpty || !(nickname ?? "").isEmpty || !emails.isEmpty || !phones.isEmpty
    }
}
