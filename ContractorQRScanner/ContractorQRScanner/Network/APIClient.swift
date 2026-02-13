import Foundation
import CommonCrypto
import UIKit
import PostHog

class APIClient {
    static let shared = APIClient()
    private let baseURL = AppConfig.apiBaseURL

    func validateQRCode(qrData: String, scanMode: String = "entry") async throws -> ValidationResponse {
        // Use authenticated scanner/validate if we have a token, else legacy qr/validate
        let token = SessionManager.shared.token
        let endpoint = token != nil ? "/api/v1/scanner/validate" : "/api/v1/qr/validate"
        let url = URL(string: "\(baseURL)\(endpoint)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 10

        // Correlation ID to link request/response/error events
        let requestId = UUID().uuidString

        // Decode QR payload for logging
        var logProperties: [String: Any] = [
            "scan_mode": scanMode,
            "app": "scanner",
            "request_id": requestId
        ]
        if let payloadData = Data(base64Encoded: qrData),
           let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
            let ts = payloadJSON["timestamp"] as? Int64 ?? 0
            let scannerTs = Date()
            let deviceTs = Date(timeIntervalSince1970: TimeInterval(ts))
            let drift = scannerTs.timeIntervalSince(deviceTs)

            logProperties["qr_timestamp"] = ts
            logProperties["qr_timestamp_iso"] = ISO8601DateFormatter().string(from: deviceTs)
            logProperties["scanner_timestamp"] = Int64(scannerTs.timeIntervalSince1970)
            logProperties["scanner_timestamp_iso"] = ISO8601DateFormatter().string(from: scannerTs)
            logProperties["clock_drift_seconds"] = round(drift * 10) / 10
            logProperties["qr_age_seconds_at_scan"] = round(drift * 10) / 10
            logProperties["totp_token"] = payloadJSON["totpToken"] as? String ?? "?"
            logProperties["nonce"] = String((payloadJSON["nonce"] as? String ?? "?").prefix(16))
            logProperties["site_code"] = payloadJSON["siteCode"] as? String ?? "?"
            logProperties["qr_access_mode"] = payloadJSON["accessMode"] as? String ?? "?"
            logProperties["contractor_id"] = payloadJSON["contractorId"] as? String ?? "?"
        }

        PostHogSDK.shared.capture("qr_validation_request", properties: logProperties)
        PostHogSDK.shared.flush()

        // Scanner endpoint expects scanner_site_code; legacy expects scan_mode
        if token != nil, let site = SessionManager.shared.assignedSite {
            let body = ScannerValidationRequest(qrData: qrData, scannerSiteCode: site.siteCode)
            request.httpBody = try JSONEncoder().encode(body)
        } else {
            let body = ValidationRequest(qrData: qrData, scanMode: scanMode)
            request.httpBody = try JSONEncoder().encode(body)
        }
        HMACSigner.sign(&request)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            PostHogSDK.shared.capture("qr_validation_error", properties: [
                "error": "network_failed",
                "error_detail": error.localizedDescription,
                "request_id": requestId,
                "app": "scanner"
            ])
            PostHogSDK.shared.flush()
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            PostHogSDK.shared.capture("qr_validation_error", properties: [
                "error": "invalid_response",
                "request_id": requestId,
                "app": "scanner"
            ])
            PostHogSDK.shared.flush()
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode

        // Try to decode the response
        if let result = try? JSONDecoder().decode(ValidationResponse.self, from: data) {
            PostHogSDK.shared.capture("qr_validation_response", properties: [
                "http_status": statusCode,
                "result_status": result.status,
                "reason": result.reason ?? "none",
                "contractor_name": result.contractor?.fullName ?? "none",
                "request_id": requestId,
                "app": "scanner"
            ])
            PostHogSDK.shared.flush()
            return result
        }

        // Fallback: extract reason from raw JSON
        let responseBody = String(data: data, encoding: .utf8) ?? "<binary>"
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let reason = json["reason"] as? String {
            let status = json["status"] as? String ?? "denied"
            PostHogSDK.shared.capture("qr_validation_response", properties: [
                "http_status": statusCode,
                "result_status": status,
                "reason": reason,
                "request_id": requestId,
                "app": "scanner"
            ])
            PostHogSDK.shared.flush()
            return ValidationResponse(
                status: "denied",
                contractor: nil,
                reason: reason
            )
        }

        // Complete decode failure
        PostHogSDK.shared.capture("qr_validation_error", properties: [
            "error": "decode_failed",
            "http_status": statusCode,
            "response_body": String(responseBody.prefix(500)),
            "request_id": requestId,
            "app": "scanner"
        ])
        PostHogSDK.shared.flush()
        throw APIError.serverError(statusCode)
    }

    // MARK: - Scanner Login

    func scannerLogin(email: String, password: String) async throws -> GuardLoginResponse {
        let url = URL(string: "\(baseURL)/api/v1/scanner/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = GuardLoginRequest(
            email: email,
            password: password,
            deviceFingerprint: DeviceFingerprint.generate(),
            deviceName: UIDevice.current.name
        )
        request.httpBody = try JSONEncoder().encode(body)
        HMACSigner.sign(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        if http.statusCode == 200 {
            return try JSONDecoder().decode(GuardLoginResponse.self, from: data)
        }

        if let errorResp = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw APIError.loginFailed(errorResp.message)
        }
        throw APIError.serverError(http.statusCode)
    }

    // MARK: - List Sites

    func listSites(token: String) async throws -> [SiteItem] {
        let url = URL(string: "\(baseURL)/api/v1/scanner/sites")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10
        HMACSigner.sign(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let result = try JSONDecoder().decode(SiteListResponse.self, from: data)
        return result.sites
    }

    // MARK: - Assign Site

    func assignSite(token: String, siteID: String) async throws {
        let url = URL(string: "\(baseURL)/api/v1/scanner/assign-site")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body = AssignSiteRequest(siteID: siteID)
        request.httpBody = try JSONEncoder().encode(body)
        HMACSigner.sign(&request)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
    }

    // MARK: - Offline Bundle

    func fetchOfflineBundle(token: String) async throws -> OfflineBundleResponse {
        let url = URL(string: "\(baseURL)/api/v1/scanner/offline-bundle")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        HMACSigner.sign(&request)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let statusCode = http?.statusCode ?? 0

        guard statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.loginFailed("Bundle failed (\(statusCode)): \(body.prefix(200))")
        }

        do {
            return try JSONDecoder().decode(OfflineBundleResponse.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.loginFailed("Decode failed: \(error.localizedDescription). Body: \(body.prefix(200))")
        }
    }
}

// MARK: - Device Fingerprint

enum DeviceFingerprint {
    static func generate() -> String {
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let model = UIDevice.current.model
        let system = UIDevice.current.systemVersion
        let raw = "\(vendor)|\(model)|\(system)"
        // Simple SHA-256 hash using CommonCrypto
        guard let data = raw.data(using: .utf8) else { return vendor }
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(Int)
    case networkError
    case loginFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error (\(code))"
        case .networkError:
            return "Network unavailable"
        case .loginFailed(let message):
            return message
        }
    }
}
