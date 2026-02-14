import CommonCrypto
import CryptoKit
import Foundation

enum EncryptedBackupServiceError: Error {
    case invalidFormat
    case decryptionFailed
}

private struct EncryptedBackupEnvelope: Codable {
    let version: Int
    let createdAt: TimeInterval
    let iterations: Int
    let salt: Data
    let combined: Data
}

struct EncryptedBackupService {
    private let version = 1
    private let saltLength = 16
    private let keyLength = 32
    private let pbkdfRounds = 210_000

    func exportBackupData(contacts: [Contact], passphrase: String) throws -> Data {
        let salt = try randomSalt(length: saltLength)
        let key = try derivedKey(from: passphrase, salt: salt, rounds: pbkdfRounds)
        let payload = try JSONEncoder().encode(contacts)
        let sealed = try AES.GCM.seal(payload, using: key)

        guard let combined = sealed.combined else {
            throw EncryptedBackupServiceError.invalidFormat
        }

        let envelope = EncryptedBackupEnvelope(
            version: version,
            createdAt: Date().timeIntervalSince1970,
            iterations: pbkdfRounds,
            salt: salt,
            combined: combined
        )
        return try JSONEncoder().encode(envelope)
    }

    func importContacts(from backupData: Data, passphrase: String) throws -> [Contact] {
        let envelope: EncryptedBackupEnvelope
        do {
            envelope = try JSONDecoder().decode(EncryptedBackupEnvelope.self, from: backupData)
        } catch {
            throw EncryptedBackupServiceError.invalidFormat
        }

        guard envelope.version == version else {
            throw EncryptedBackupServiceError.invalidFormat
        }

        let key = try derivedKey(from: passphrase, salt: envelope.salt, rounds: envelope.iterations)

        do {
            let sealed = try AES.GCM.SealedBox(combined: envelope.combined)
            let plaintext = try AES.GCM.open(sealed, using: key)
            return try JSONDecoder().decode([Contact].self, from: plaintext)
        } catch {
            throw EncryptedBackupServiceError.decryptionFailed
        }
    }

    private func randomSalt(length: Int) throws -> Data {
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, length, bytes.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw EncryptedBackupServiceError.invalidFormat
        }
        return data
    }

    private func derivedKey(from passphrase: String, salt: Data, rounds: Int) throws -> SymmetricKey {
        guard let passwordData = passphrase.data(using: .utf8) else {
            throw EncryptedBackupServiceError.invalidFormat
        }

        var derived = Data(count: keyLength)

        let status = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(rounds),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw EncryptedBackupServiceError.invalidFormat
        }

        return SymmetricKey(data: derived)
    }
}
