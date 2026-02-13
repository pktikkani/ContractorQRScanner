import SwiftUI

struct AppTheme {
    // Habita — Warm minimalist palette inspired by Smart Home Hub UI
    // NO greens — exclusively warm earth tones

    // Backgrounds
    static let background = Color(red: 0.96, green: 0.94, blue: 0.92)       // #F5F0EB warm cream
    static let cardBackground = Color.white                                    // pure white cards
    static let surfaceBackground = Color(red: 0.93, green: 0.90, blue: 0.87) // #EDE6DE warm beige surface
    static let cardBackgroundElevated = Color(red: 0.98, green: 0.97, blue: 0.95) // #FAF8F3 off-white

    // Primary — terracotta/burnt coral
    static let primary = Color(red: 0.78, green: 0.36, blue: 0.25)    // #C75B3F terracotta
    static let secondary = Color(red: 0.83, green: 0.77, blue: 0.70)  // #D4C5B2 warm tan

    // Status colors — all warm earth tones, no greens
    static let success = Color(red: 0.65, green: 0.49, blue: 0.36)    // #A67D5C warm bronze
    static let danger = Color(red: 0.84, green: 0.45, blue: 0.38)     // #D67360 coral
    static let warning = Color(red: 0.85, green: 0.62, blue: 0.30)    // #D99E4D warm amber

    // Text
    static let textPrimary = Color(red: 0.16, green: 0.16, blue: 0.16) // #2A2A2A dark charcoal
    static let textSecondary = Color(red: 0.55, green: 0.50, blue: 0.47) // #8C8078 warm gray

    // Light text for use on dark/colored backgrounds
    static let textOnPrimary = Color.white

    // Gradients (subtle, warm)
    static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.78, green: 0.36, blue: 0.25), // #C75B3F
            Color(red: 0.72, green: 0.30, blue: 0.20)  // #B84D33 slightly deeper
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [
            Color(red: 0.65, green: 0.49, blue: 0.36), // #A67D5C warm bronze
            Color(red: 0.58, green: 0.42, blue: 0.30)  // #946B4D deeper bronze
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [
            Color(red: 0.84, green: 0.45, blue: 0.38), // #D67360 coral
            Color(red: 0.76, green: 0.38, blue: 0.32)  // #C26152 deeper coral
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Shadows — soft warm shadows
    static let cardShadow = Color(red: 0.60, green: 0.55, blue: 0.50).opacity(0.12)
    static let primaryShadow = Color(red: 0.78, green: 0.36, blue: 0.25).opacity(0.25)
    static let glowShadow = Color(red: 0.78, green: 0.36, blue: 0.25).opacity(0.20)

    static let cornerRadius: CGFloat = 20
}
