import Combine
import Contacts
import Foundation

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
    @Published var isPresentingForm = false
    @Published var form = ContactFormState()
    @Published var selectedContactId: UUID?
    @Published var errorMessage: String?

    private let store = EncryptedContactsStore()
    private let reminderService = BirthdayReminderService.shared

    var filteredContacts: [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return contacts.sorted { $0.updatedAt > $1.updatedAt } }

        return contacts.filter { contact in
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
                contact.tags.joined(separator: " "),
            ].joined(separator: " ").lowercased()
            return haystack.contains(trimmed)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    func bootstrap() async {
        do {
            var localContacts = try await store.loadContacts()

            if localContacts.isEmpty {
                localContacts = try await store.ensureSeedDataIfEmpty(seedContacts: Contact.sampleSeed)
            }

            contacts = localContacts.sorted { $0.updatedAt > $1.updatedAt }
            await syncBirthdayReminders()
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
        form.relationships = contact.relationships
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
            emails: parseCSV(form.emails),
            facebook: parseOptionalCSV(form.facebook),
            linkedin: parseOptionalCSV(form.linkedin),
            instagram: parseOptionalCSV(form.instagram),
            x: parseOptionalCSV(form.x),
            notes: normalizedOptional(form.notes),
            tags: parseCSV(form.tags),
            relationships: form.relationships,
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
            await syncBirthdayReminders()
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
            await syncBirthdayReminders()
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
            await syncBirthdayReminders()
        } catch {
            errorMessage = L10n.tr("error.contact.import.save")
        }
    }

    var availableRelationshipTargets: [Contact] {
        contacts.filter { $0.id != selectedContactId }.sorted { $0.displayName < $1.displayName }
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

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func syncBirthdayReminders() async {
        let rules = BirthdayReminderRule.loadFromDefaults()
        await reminderService.syncBirthdays(for: contacts, rules: rules)
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
