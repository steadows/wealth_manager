import SwiftUI

/// Design tokens from the Holographic JARVIS design system.
/// All colors used across the Wealth Manager app are defined here.
enum WMColors {

    // MARK: - Backgrounds

    /// Dark background start color (#070b14)
    static let backgroundStart = Color(red: 7 / 255, green: 11 / 255, blue: 20 / 255)

    /// Dark background end color (#0c1220)
    static let backgroundEnd = Color(red: 12 / 255, green: 18 / 255, blue: 32 / 255)

    /// Linear gradient background for app chrome
    static let background = LinearGradient(
        colors: [backgroundStart, backgroundEnd],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Glass

    /// Frosted glass background (white 10% opacity)
    static let glassBg = Color.white.opacity(0.10)

    /// Frosted glass border (white 12% opacity)
    static let glassBorder = Color.white.opacity(0.12)

    // MARK: - Brand

    /// Primary electric blue (#3b82f6)
    static let primary = Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)

    /// Secondary cyan (#06b6d4)
    static let secondary = Color(red: 6 / 255, green: 182 / 255, blue: 212 / 255)

    /// Tertiary teal (#14b8a6)
    static let tertiary = Color(red: 20 / 255, green: 184 / 255, blue: 166 / 255)

    /// Glow / ice blue (#7dd3fc)
    static let glow = Color(red: 125 / 255, green: 211 / 255, blue: 252 / 255)

    // MARK: - Semantic

    /// Positive / green (#22c55e)
    static let positive = Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)

    /// Negative / red (#ef4444)
    static let negative = Color(red: 239 / 255, green: 68 / 255, blue: 68 / 255)

    // MARK: - Text

    /// Primary text color (white)
    static let textPrimary = Color.white

    /// Muted text color (white 50% opacity)
    static let textMuted = Color.white.opacity(0.50)
}
