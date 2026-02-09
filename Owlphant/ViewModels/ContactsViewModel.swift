import Combine
import Foundation

struct ContactFormState {
    var firstName = ""
    var lastName = ""
    var nickname = ""
    var birthday = "1995-01-01"
    var photoData: Data?
    var placeOfBirth = ""
    var placeOfLiving = ""
    var company = ""
    var workPosition = ""
    var phones = ""
    var emails = ""
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

    var filteredContacts: [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return contacts.sorted { $0.updatedAt > $1.updatedAt } }

        return contacts.filter { contact in
            let haystack = [
                contact.firstName,
                contact.lastName,
                contact.nickname ?? "",
                contact.company ?? "",
                contact.workPosition ?? "",
                contact.emails.joined(separator: " "),
                contact.phones.joined(separator: " "),
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
            isReady = true
        } catch {
            errorMessage = "Could not load encrypted storage."
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
        form.birthday = contact.birthday ?? "1995-01-01"
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
        guard !first.isEmpty || !last.isEmpty else {
            errorMessage = "Please add at least a first or last name."
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
            cancelForm()
        } catch {
            errorMessage = "Could not save contact."
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
        } catch {
            errorMessage = "Could not delete contact."
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
        contacts.first(where: { $0.id == id })?.displayName ?? "Unknown contact"
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

    private func normalizedOptional(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
