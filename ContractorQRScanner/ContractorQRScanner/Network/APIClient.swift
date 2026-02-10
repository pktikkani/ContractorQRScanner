import Foundation

class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL

    func validateQRCode(qrData: String) async throws -> ValidationResponse {
        let url = URL(string: "\(baseURL)/api/v1/qr/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ValidationRequest(qrData: qrData)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Try to decode the response body regardless of status code
        // The backend returns status/reason even on 400 errors
        if let result = try? JSONDecoder().decode(ValidationResponse.self, from: data) {
            return result
        }

        // If we can't decode as ValidationResponse, try to get the reason from raw JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let reason = json["reason"] as? String {
            return ValidationResponse(
                status: "denied",
                contractor: nil,
                reason: reason
            )
        }

        throw APIError.serverError(httpResponse.statusCode)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (\(code))"
        case .networkError:
            return "Network unavailable"
        }
    }
}
