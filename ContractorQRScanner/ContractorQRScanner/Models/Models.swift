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

// MARK: - Scan History

struct ScanHistoryEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let contractorName: String
    let company: String?
    let email: String?
    let result: String // "granted" or "denied"
    let reason: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), contractorName: String, company: String? = nil, email: String? = nil, result: String, reason: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.contractorName = contractorName
        self.company = company
        self.email = email
        self.result = result
        self.reason = reason
    }

    init(from response: ValidationResponse) {
        self.id = UUID()
        self.timestamp = Date()
        self.contractorName = response.contractor?.fullName ?? "Unknown"
        self.company = response.contractor?.company
        self.email = response.contractor?.email
        self.result = response.status
        self.reason = response.reason
    }
}
