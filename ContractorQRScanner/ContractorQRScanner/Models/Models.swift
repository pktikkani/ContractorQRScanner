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
}
