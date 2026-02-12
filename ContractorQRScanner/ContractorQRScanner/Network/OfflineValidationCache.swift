import Foundation

class OfflineValidationCache {
    static let shared = OfflineValidationCache()

    private let defaults = UserDefaults.standard
    private let maxEntries = 200

    private enum Keys {
        static let cachedValidations = "offline_cached_validations"
    }

    // MARK: - Cache a successful validation

    func cacheGrantedValidation(contractorId: String, response: ValidationResponse) {
        guard response.isGranted, let contractor = response.contractor else { return }

        var entries = getAllCachedEntries()
        let entry = CachedValidation(
            contractorId: contractorId,
            contractor: contractor,
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

    // MARK: - Offline validation attempt

    /// Attempts basic offline validation. Returns a ValidationResponse if the contractor
    /// was recently granted access and the cached data is still within 48 hours.
    func attemptOfflineValidation(qrData: String) -> ValidationResponse? {
        // Try to decode the QR payload to get the contractor ID
        guard let data = Data(base64Encoded: qrData),
              let payload = try? JSONDecoder().decode(QRPayloadMinimal.self, from: data) else {
            return nil
        }

        let entries = getAllCachedEntries()
        guard let cached = entries.first(where: { $0.contractorId == payload.contractorId }) else {
            return nil
        }

        // Only use cache if within 48 hours
        guard Date().timeIntervalSince(cached.cachedAt) < 48 * 3600 else {
            return nil
        }

        return ValidationResponse(
            status: "granted",
            contractor: cached.contractor,
            reason: nil
        )
    }

    // MARK: - Persistence

    private func getAllCachedEntries() -> [CachedValidation] {
        guard let data = defaults.data(forKey: Keys.cachedValidations) else { return [] }
        return (try? JSONDecoder().decode([CachedValidation].self, from: data)) ?? []
    }

    private func saveCachedEntries(_ entries: [CachedValidation]) {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Keys.cachedValidations)
        }
    }

    func clearAll() {
        defaults.removeObject(forKey: Keys.cachedValidations)
    }
}

// MARK: - Supporting Types

struct CachedValidation: Codable {
    let contractorId: String
    let contractor: ContractorInfo
    let cachedAt: Date
}

/// Minimal QR payload to extract contractor ID without importing crypto
struct QRPayloadMinimal: Codable {
    let contractorId: String
}
