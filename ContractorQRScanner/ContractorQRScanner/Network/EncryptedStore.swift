import Foundation
import CryptoKit

/// AES-GCM encrypted storage backed by files + Keychain-stored key.
/// Used to protect sensitive offline data (TOTP seeds, contractor info).
final class EncryptedStore {
    static let shared = EncryptedStore()

    private let keyTag = "com.nubewired.contractorqrscanner.encryptionKey"
    private let fileManager = FileManager.default
    private let encryptedDir: URL

    private init() {
        let docs = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        encryptedDir = docs.appendingPathComponent("EncryptedCache", isDirectory: true)
        try? fileManager.createDirectory(at: encryptedDir, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let plaintext = try JSONEncoder().encode(value)
        let encrypted = try encrypt(plaintext)
        let fileURL = encryptedDir.appendingPathComponent(key)
        try encrypted.write(to: fileURL, options: .completeFileProtectionUnlessOpen)
    }

    func load<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T {
        let fileURL = encryptedDir.appendingPathComponent(key)
        let encrypted = try Data(contentsOf: fileURL)
        let plaintext = try decrypt(encrypted)
        return try JSONDecoder().decode(type, from: plaintext)
    }

    func delete(forKey key: String) {
        let fileURL = encryptedDir.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }

    func deleteAll() {
        try? fileManager.removeItem(at: encryptedDir)
        try? fileManager.createDirectory(at: encryptedDir, withIntermediateDirectories: true)
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptedStoreError.encryptionFailed
        }
        return combined
    }

    private func decrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - Key Management (Keychain-backed)

    private func getOrCreateKey() throws -> SymmetricKey {
        if let existingKeyData = loadKeyFromKeychain() {
            return SymmetricKey(data: existingKeyData)
        }

        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        saveKeyToKeychain(keyData)
        return newKey
    }

    private func loadKeyFromKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecAttrService as String: "com.nubewired.contractorqrscanner.encryption",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private func saveKeyToKeychain(_ keyData: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecAttrService as String: "com.nubewired.contractorqrscanner.encryption"
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = keyData
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    enum EncryptedStoreError: Error {
        case encryptionFailed
    }
}
