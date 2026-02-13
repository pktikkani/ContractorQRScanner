import Foundation

struct AppConfig {
    static let apiBaseURL = "https://contractor-api.nubewired.com"
}

struct ValidationResponse: Codable {
    let status: String
    let contractor: ContractorInfo?
    let reason: String?

    var isGranted: Bool { status == "granted" }
}

struct ContractorInfo: Codable {
    let id: String
    let fullName: String
    let company: String?
    let email: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, fullName, company, email
        case photoUrl = "photo_url"
    }
}

struct ValidationRequest: Codable {
    let qrData: String
    let scanMode: String

    enum CodingKeys: String, CodingKey {
        case qrData
        case scanMode = "scan_mode"
    }
}

// MARK: - Scanner Auth

struct GuardLoginRequest: Codable {
    let email: String
    let password: String
    let deviceFingerprint: String
    let deviceName: String

    enum CodingKeys: String, CodingKey {
        case email, password
        case deviceFingerprint = "device_fingerprint"
        case deviceName = "device_name"
    }
}

struct GuardLoginResponse: Codable {
    let token: String
    let guardName: String
    let scannerID: String
    let assignedSite: ScannerSiteInfo?
    let hmacKey: String

    enum CodingKeys: String, CodingKey {
        case token
        case guardName = "guard_name"
        case scannerID = "scanner_id"
        case assignedSite = "assigned_site"
        case hmacKey = "hmac_key"
    }
}

struct ScannerSiteInfo: Codable {
    let siteID: String
    let siteCode: String
    let siteName: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
        case siteCode = "site_code"
        case siteName = "site_name"
    }
}

struct SiteListResponse: Codable {
    let sites: [SiteItem]
}

struct SiteItem: Codable, Identifiable {
    let id: String
    let siteCode: String
    let siteName: String
    let address: String
    let latitude: Double
    let longitude: Double
    let geofenceRadius: Int
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case siteCode = "site_code"
        case siteName = "site_name"
        case address, latitude, longitude
        case geofenceRadius = "geofence_radius"
        case isActive = "is_active"
    }
}

struct AssignSiteRequest: Codable {
    let siteID: String

    enum CodingKeys: String, CodingKey {
        case siteID = "site_id"
    }
}

struct OfflineBundleResponse: Codable {
    let siteCode: String
    let siteName: String
    let contractors: [OfflineBundleContractor]
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case siteCode = "site_code"
        case siteName = "site_name"
        case contractors
        case generatedAt = "generated_at"
    }
}

struct ScannerValidationRequest: Codable {
    let qrData: String
    let scannerSiteCode: String

    enum CodingKeys: String, CodingKey {
        case qrData
        case scannerSiteCode = "scanner_site_code"
    }
}

struct ErrorResponse: Codable {
    let error: String
    let message: String
}

// MARK: - Scan History

struct ScanHistoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let contractorName: String
    let company: String?
    let email: String?
    let result: String // "granted" or "denied"
    let reason: String?
    let scanMode: String? // "entry" or "exit"

    init(id: UUID = UUID(), timestamp: Date = Date(), contractorName: String, company: String? = nil, email: String? = nil, result: String, reason: String? = nil, scanMode: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.contractorName = contractorName
        self.company = company
        self.email = email
        self.result = result
        self.reason = reason
        self.scanMode = scanMode
    }

    init(from response: ValidationResponse, scanMode: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.contractorName = response.contractor?.fullName ?? "Unknown"
        self.company = response.contractor?.company
        self.email = response.contractor?.email
        self.result = response.status
        self.reason = response.reason
        self.scanMode = scanMode
    }
}
