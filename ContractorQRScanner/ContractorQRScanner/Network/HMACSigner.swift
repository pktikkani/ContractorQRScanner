import Foundation
import CryptoKit

/// HMAC-SHA256 request signing (Security Layer 7).
/// Signs: HMAC-SHA256(timestamp + "." + body, signingKey)
/// The signing key is delivered by the backend at login and stored in the Keychain.
enum HMACSigner {

    /// Adds X-Signature and X-Timestamp headers to a URLRequest.
    /// If no HMAC key is stored yet (pre-login), headers are omitted — the
    /// login endpoint itself does not require HMAC.
    static func sign(_ request: inout URLRequest) {
        guard let signingKey = KeychainHelper.load(key: "hmac_signing_key"),
              !signingKey.isEmpty else {
            return
        }

        let timestamp = String(Int(Date().timeIntervalSince1970))
        let body = request.httpBody ?? Data()

        // Build signing data: "timestamp." + body bytes
        var signingData = Data((timestamp + ".").utf8)
        signingData.append(body)

        let key = SymmetricKey(data: Data(signingKey.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: signingData, using: key)
        let signature = mac.map { String(format: "%02x", $0) }.joined()

        request.setValue(signature, forHTTPHeaderField: "X-Signature")
        request.setValue(timestamp, forHTTPHeaderField: "X-Timestamp")
    }
}
