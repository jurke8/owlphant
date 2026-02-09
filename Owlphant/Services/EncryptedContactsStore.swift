import CryptoKit
import Foundation

private struct EncryptedEnvelope: Codable {
    let combined: Data
}

actor EncryptedContactsStore {
    private let keychainAccount = "owlphant.data.encryption.key"

    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Owlphant", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("contacts.enc")
    }

    func bootstrap(seedContacts: [Contact]) async throws -> [Contact] {
        let existing = try loadContacts()
        if !existing.isEmpty {
            return existing.sorted { $0.updatedAt > $1.updatedAt }
        }

        try saveContacts(seedContacts)
        return seedContacts.sorted { $0.updatedAt > $1.updatedAt }
    }

    func ensureSeedDataIfEmpty(seedContacts: [Contact]) throws -> [Contact] {
        let existing = try loadContacts()
        if !existing.isEmpty {
            return existing.sorted { $0.updatedAt > $1.updatedAt }
        }
        try saveContacts(seedContacts)
        return seedContacts.sorted { $0.updatedAt > $1.updatedAt }
    }

    func loadContacts() throws -> [Contact] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        let encryptedData = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder().decode(EncryptedEnvelope.self, from: encryptedData)
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.SealedBox(combined: envelope.combined)
        let plaintext = try AES.GCM.open(sealed, using: key)
        return try JSONDecoder().decode([Contact].self, from: plaintext)
    }

    func saveContacts(_ contacts: [Contact]) throws {
        let key = try loadOrCreateKey()
        let plaintext = try JSONEncoder().encode(contacts)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "EncryptedContactsStore", code: -1)
        }
        let envelope = EncryptedEnvelope(combined: combined)
        let encryptedData = try JSONEncoder().encode(envelope)
        try encryptedData.write(to: fileURL, options: Data.WritingOptions.atomic)
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let keyData = try KeychainService.read(account: keychainAccount) {
            return SymmetricKey(data: keyData)
        }

        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try KeychainService.save(keyData, account: keychainAccount)
        return key
    }
}
