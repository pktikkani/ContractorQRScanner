import SwiftUI

struct AppTheme {
    // Background
    static let background = Color(red: 0.06, green: 0.07, blue: 0.11)
    static let cardBackground = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let surfaceBackground = Color(red: 0.08, green: 0.09, blue: 0.14)

    // Primary colors
    static let primary = Color(red: 0.0, green: 0.8, blue: 0.85)
    static let secondary = Color(red: 0.4, green: 0.35, blue: 1.0)

    // Status colors
    static let success = Color(red: 0.0, green: 0.85, blue: 0.45)
    static let danger = Color(red: 1.0, green: 0.25, blue: 0.35)
    static let warning = Color(red: 1.0, green: 0.75, blue: 0.0)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.55)

    // Gradients
    static let primaryGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.8, blue: 0.85), Color(red: 0.0, green: 0.6, blue: 0.9)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [Color(red: 0.0, green: 0.85, blue: 0.45), Color(red: 0.0, green: 0.7, blue: 0.35)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let dangerGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.25, blue: 0.35), Color(red: 0.85, green: 0.15, blue: 0.25)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 16
}
