import Foundation

class OfflineValidationCache {
    static let shared = OfflineValidationCache()

    private let store = EncryptedStore.shared
    private let defaults = UserDefaults.standard
    private let maxEntries = 500

    private enum Keys {
        static let cachedValidations = "offline_cached_validations"
        static let usedNonces = "offline_used_nonces"
    }

    // MARK: - Cache a successful validation (includes TOTP seed from server response)

    func cacheGrantedValidation(contractorId: String, response: ValidationResponse, totpSeed: String? = nil) {
        guard response.isGranted, let contractor = response.contractor else { return }

        var entries = getAllCachedEntries()
        let entry = CachedValidation(
            contractorId: contractorId,
            contractor: contractor,
            totpSeed: totpSeed ?? entries.first(where: { $0.contractorId == contractorId })?.totpSeed,
            cachedAt: Date()
        )

        // Update or insert
        entries.removeAll { $0.contractorId == contractorId }
        entries.insert(entry, at: 0)

        // Trim to max
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveCachedEntries(entries)
    }

    // MARK: - Store offline bundle from server

    func storeOfflineBundle(contractors: [OfflineBundleContractor]) {
        var entries = getAllCachedEntries()

        for c in contractors {
            let contractor = ContractorInfo(
                id: c.id,
                fullName: "\(c.firstName) \(c.lastName)",
                company: c.company.isEmpty ? nil : c.company,
                email: nil,
                photoUrl: c.photoUrl?.isEmpty == false ? c.photoUrl : nil
            )
            let entry = CachedValidation(
                contractorId: c.id,
                contractor: contractor,
                totpSeed: c.totpSeed,
                cachedAt: Date()
            )
            entries.removeAll { $0.contractorId == c.id }
            entries.append(entry)
        }

        // Trim
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveCachedEntries(entries)
    }

    // MARK: - Full offline validation

    /// Attempts offline validation with TOTP verification and replay protection.
    /// Falls back to basic contractor-ID-known check if no TOTP seed is cached.
    func attemptOfflineValidation(qrData: String) -> ValidationResponse? {
        guard let data = Data(base64Encoded: qrData),
              let payload = try? JSONDecoder().decode(QRPayloadFull.self, from: data) else {
            return nil
        }

        let entries = getAllCachedEntries()
        guard let cached = entries.first(where: { $0.contractorId == payload.contractorId }) else {
            return nil
        }

        // Check cache freshness (48 hours)
        guard Date().timeIntervalSince(cached.cachedAt) < 48 * 3600 else {
            return nil
        }

        // Check QR timestamp freshness (90 seconds)
        let now = Date().timeIntervalSince1970
        let qrAge = now - TimeInterval(payload.timestamp)
        if qrAge > 90 || qrAge < -90 {
            return ValidationResponse(
                status: "denied",
                contractor: cached.contractor,
                reason: "QR code expired (offline check)"
            )
        }

        // Replay protection — check nonce
        if isNonceUsed(payload.nonce) {
            return ValidationResponse(
                status: "denied",
                contractor: cached.contractor,
                reason: "QR code already used (offline check)"
            )
        }

        // TOTP verification (if we have the seed)
        if let seed = cached.totpSeed, !seed.isEmpty {
            let qrTime = Date(timeIntervalSince1970: TimeInterval(payload.timestamp))
            if !TOTPValidator.validate(token: payload.totpToken, seed: seed, timestamp: qrTime) {
                return ValidationResponse(
                    status: "denied",
                    contractor: cached.contractor,
                    reason: "Invalid security token (offline check)"
                )
            }
        }

        // Mark nonce as used
        markNonceUsed(payload.nonce)

        return ValidationResponse(
            status: "granted",
            contractor: cached.contractor,
            reason: nil
        )
    }

    // MARK: - Nonce replay protection (ephemeral, UserDefaults is fine)

    private func isNonceUsed(_ nonce: String) -> Bool {
        let nonces = getUsedNonces()
        return nonces.contains(where: { $0.nonce == nonce })
    }

    private func markNonceUsed(_ nonce: String) {
        var nonces = getUsedNonces()
        nonces.append(UsedNonce(nonce: nonce, usedAt: Date()))

        // Purge nonces older than 5 minutes (same as server Redis TTL)
        let cutoff = Date().addingTimeInterval(-300)
        nonces.removeAll { $0.usedAt < cutoff }

        if let data = try? JSONEncoder().encode(nonces) {
            defaults.set(data, forKey: Keys.usedNonces)
        }
    }

    private func getUsedNonces() -> [UsedNonce] {
        guard let data = defaults.data(forKey: Keys.usedNonces) else { return [] }
        return (try? JSONDecoder().decode([UsedNonce].self, from: data)) ?? []
    }

    // MARK: - Encrypted Persistence

    private func getAllCachedEntries() -> [CachedValidation] {
        (try? store.load([CachedValidation].self, forKey: Keys.cachedValidations)) ?? []
    }

    private func saveCachedEntries(_ entries: [CachedValidation]) {
        try? store.save(entries, forKey: Keys.cachedValidations)
    }

    var cachedContractorCount: Int {
        getAllCachedEntries().count
    }

    func clearAll() {
        store.delete(forKey: Keys.cachedValidations)
        defaults.removeObject(forKey: Keys.usedNonces)
    }
}

// MARK: - Supporting Types

struct CachedValidation: Codable {
    let contractorId: String
    let contractor: ContractorInfo
    let totpSeed: String?
    let cachedAt: Date
}

/// Full QR payload for offline TOTP verification
struct QRPayloadFull: Codable {
    let contractorId: String
    let timestamp: Int64
    let totpToken: String
    let siteCode: String
    let nonce: String
    let deviceFingerprint: String
    let accessMode: String?
}

/// Offline bundle contractor (matches Go backend OfflineBundleContractor)
struct OfflineBundleContractor: Codable {
    let id: String
    let firstName: String
    let lastName: String
    let company: String
    let photoUrl: String?
    let totpSeed: String

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case company
        case photoUrl = "photo_url"
        case totpSeed = "totp_seed"
    }
}

struct UsedNonce: Codable {
    let nonce: String
    let usedAt: Date
}
