import SwiftUI

/// Typography scale for the Wealth Manager app.
/// Uses Inter font with system font fallback.
enum WMTypography {

    // MARK: - Private Helpers

    /// Returns Inter font if available, otherwise falls back to system design.
    private static func font(size: CGFloat, weight: Font.Weight) -> Font {
        let interName: String = switch weight {
        case .thin: "Inter-Thin"
        case .light: "Inter-Light"
        case .regular: "Inter-Regular"
        case .medium: "Inter-Medium"
        case .semibold: "Inter-SemiBold"
        case .bold: "Inter-Bold"
        case .heavy: "Inter-ExtraBold"
        case .black: "Inter-Black"
        default: "Inter-Regular"
        }

        // Attempt to load Inter; fall back to system font.
        if NSFont(name: interName, size: size) != nil {
            return .custom(interName, size: size)
        }
        return .system(size: size, weight: weight)
    }

    // MARK: - Styles

    /// 48pt thin — hero net-worth number
    static let heroNumber: Font = font(size: 48, weight: .thin)

    /// 20pt semibold — section headings
    static let heading: Font = font(size: 20, weight: .semibold)

    /// 16pt medium — subheadings
    static let subheading: Font = font(size: 16, weight: .medium)

    /// 14pt regular — body text
    static let body: Font = font(size: 14, weight: .regular)

    /// 12pt regular — captions and metadata
    static let caption: Font = font(size: 12, weight: .regular)

    /// 14pt regular + muted color — secondary body text
    static let muted: Font = font(size: 14, weight: .regular)
}

extension View {
    /// Applies the muted typography style (body size with WMColors.textMuted).
    func wmMuted() -> some View {
        self
            .font(WMTypography.muted)
            .foregroundStyle(WMColors.textMuted)
    }
}
