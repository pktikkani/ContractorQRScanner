import Combine
import Foundation
import Security

@MainActor
class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published var isAuthenticated = false
    @Published var guardName: String = ""
    @Published var scannerID: String = ""
    @Published var assignedSite: AssignedSite?

    private enum KeychainKey {
        static let token = "scanner_jwt_token"
        static let guardName = "scanner_guard_name"
        static let scannerID = "scanner_scanner_id"
        static let assignedSiteJSON = "scanner_assigned_site"
    }

    private init() {
        loadSession()
    }

    // MARK: - Public

    func saveLogin(token: String, guardName: String, scannerID: String, assignedSite: AssignedSite?) {
        KeychainHelper.save(key: KeychainKey.token, value: token)
        KeychainHelper.save(key: KeychainKey.guardName, value: guardName)
        KeychainHelper.save(key: KeychainKey.scannerID, value: scannerID)

        if let site = assignedSite, let data = try? JSONEncoder().encode(site) {
            KeychainHelper.save(key: KeychainKey.assignedSiteJSON, data: data)
        }

        self.isAuthenticated = true
        self.guardName = guardName
        self.scannerID = scannerID
        self.assignedSite = assignedSite
    }

    func saveAssignedSite(_ site: AssignedSite) {
        self.assignedSite = site
        if let data = try? JSONEncoder().encode(site) {
            KeychainHelper.save(key: KeychainKey.assignedSiteJSON, data: data)
        }
    }

    var token: String? {
        KeychainHelper.load(key: KeychainKey.token)
    }

    func logout() {
        KeychainHelper.delete(key: KeychainKey.token)
        KeychainHelper.delete(key: KeychainKey.guardName)
        KeychainHelper.delete(key: KeychainKey.scannerID)
        KeychainHelper.delete(key: KeychainKey.assignedSiteJSON)
        KeychainHelper.delete(key: "hmac_signing_key")

        isAuthenticated = false
        guardName = ""
        scannerID = ""
        assignedSite = nil

        OfflineValidationCache.shared.clearAll()
    }

    // MARK: - Private

    private func loadSession() {
        guard let token = KeychainHelper.load(key: KeychainKey.token), !token.isEmpty else {
            isAuthenticated = false
            return
        }

        // Check JWT expiry (scanner tokens are 30 days)
        if isTokenExpired(token) {
            logout()
            return
        }

        self.guardName = KeychainHelper.load(key: KeychainKey.guardName) ?? ""
        self.scannerID = KeychainHelper.load(key: KeychainKey.scannerID) ?? ""

        if let siteData = KeychainHelper.loadData(key: KeychainKey.assignedSiteJSON) {
            self.assignedSite = try? JSONDecoder().decode(AssignedSite.self, from: siteData)
        }

        self.isAuthenticated = true
    }

    private func isTokenExpired(_ token: String) -> Bool {
        let parts = token.split(separator: ".")
        guard parts.count == 3,
              let payloadData = base64URLDecode(String(parts[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        return Date().timeIntervalSince1970 > exp
    }

    private func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}

// MARK: - AssignedSite Model

struct AssignedSite: Codable, Equatable {
    let siteID: String
    let siteCode: String
    let siteName: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case siteCode = "site_code"
        case siteName = "site_name"
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    static func save(key: String, value: String) {
        save(key: key, data: Data(value.utf8))
    }

    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.nubewired.contractorqrscanner"
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func load(key: String) -> String? {
        guard let data = loadData(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func loadData(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.nubewired.contractorqrscanner",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: "com.nubewired.contractorqrscanner"
        ]
        SecItemDelete(query as CFDictionary)
    }
}
