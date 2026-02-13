import Foundation
import CommonCrypto

/// Validates TOTP tokens offline using the same algorithm as the contractor app.
/// Used for Security Layer 1 verification during offline scanning.
struct TOTPValidator {
    static let period: TimeInterval = 30.0
    static let digits: Int = 6
    /// Allow ±1 period skew (90 second window), same as backend
    static let skew: UInt64 = 1

    /// Validates a TOTP token against a seed, allowing ±1 period skew.
    static func validate(token: String, seed: String, timestamp: Date = Date()) -> Bool {
        let currentCounter = UInt64(timestamp.timeIntervalSince1970 / period)

        for offset in 0...skew {
            // Check current and previous counters
            if let generated = try? generateToken(seed: seed, counter: currentCounter - offset),
               generated == token {
                return true
            }
            // Check future counter (clock drift)
            if offset > 0, let generated = try? generateToken(seed: seed, counter: currentCounter + offset),
               generated == token {
                return true
            }
        }
        return false
    }

    private static func generateToken(seed: String, counter: UInt64) throws -> String {
        guard let keyData = base32Decode(seed) else {
            throw ValidationError.invalidSeed
        }

        var bigCounter = counter.bigEndian
        let counterData = Data(bytes: &bigCounter, count: MemoryLayout<UInt64>.size)

        // HMAC-SHA256
        var hmac = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        counterData.withUnsafeBytes { dataPtr in
            keyData.withUnsafeBytes { keyPtr in
                CCHmac(
                    CCHmacAlgorithm(kCCHmacAlgSHA256),
                    keyPtr.baseAddress, keyData.count,
                    dataPtr.baseAddress, counterData.count,
                    &hmac
                )
            }
        }

        // Dynamic truncation (RFC 4226)
        let offset = Int(hmac[hmac.count - 1] & 0x0f)
        let truncated = (UInt32(hmac[offset]) & 0x7f) << 24
            | UInt32(hmac[offset + 1]) << 16
            | UInt32(hmac[offset + 2]) << 8
            | UInt32(hmac[offset + 3])

        let otp = truncated % UInt32(pow(10.0, Double(digits)))
        return String(format: "%0\(digits)d", otp)
    }

    private static func base32Decode(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let clean = string.replacingOccurrences(of: "=", with: "").uppercased()
        var bits = ""

        for char in clean {
            guard let idx = alphabet.firstIndex(of: char) else { return nil }
            let value = alphabet.distance(from: alphabet.startIndex, to: idx)
            let binary = String(value, radix: 2)
            bits += String(repeating: "0", count: 5 - binary.count) + binary
        }

        var data = Data()
        var i = bits.startIndex
        while i < bits.endIndex {
            let end = bits.index(i, offsetBy: 8, limitedBy: bits.endIndex) ?? bits.endIndex
            let byte = bits[i..<end]
            if byte.count == 8, let value = UInt8(byte, radix: 2) {
                data.append(value)
            }
            i = end
        }
        return data
    }

    enum ValidationError: Error {
        case invalidSeed
    }
}
