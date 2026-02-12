import Combine
import Foundation

struct VersionCheckResponse: Codable {
    let minVersion: String
    let latestVersion: String
    let forceUpdate: Bool
    let updateUrl: String?

    enum CodingKeys: String, CodingKey {
        case minVersion = "min_version"
        case latestVersion = "latest_version"
        case forceUpdate = "force_update"
        case updateUrl = "update_url"
    }
}

@MainActor
class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published var updateRequired = false
    @Published var updateUrl: String?

    private let baseURL = AppConfig.apiBaseURL

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    func checkForUpdate() async {
        guard let url = URL(string: "\(baseURL)/api/v1/app/version-check?platform=ios&version=\(currentVersion)") else {
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let versionCheck = try JSONDecoder().decode(VersionCheckResponse.self, from: data)

            if versionCheck.forceUpdate && isVersionLessThan(currentVersion, minimum: versionCheck.minVersion) {
                updateRequired = true
                updateUrl = versionCheck.updateUrl
            }
        } catch {
            #if DEBUG
            print("Version check failed: \(error)")
            #endif
        }
    }

    private func isVersionLessThan(_ current: String, minimum: String) -> Bool {
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        let minimumParts = minimum.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentParts.count, minimumParts.count) {
            let c = i < currentParts.count ? currentParts[i] : 0
            let m = i < minimumParts.count ? minimumParts[i] : 0

            if c < m { return true }
            if c > m { return false }
        }

        return false
    }
}
