import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Typography scale for the Wealth Manager app.
/// Uses Inter font with system font fallback.
enum WMTypography {

    // MARK: - Private Helpers

    /// Maps font sizes to semantic Dynamic Type text styles for scaling.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 48...: return .largeTitle
        case 20..<48: return .title3
        case 16..<20: return .body
        case 14..<16: return .subheadline
        default: return .caption
        }
    }

    /// Returns Inter font if available, otherwise falls back to system design.
    /// All fonts scale with Dynamic Type via `relativeTo`.
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

        let style = textStyle(for: size)

        // Attempt to load Inter; fall back to system font.
        #if canImport(AppKit)
        let fontAvailable = NSFont(name: interName, size: size) != nil
        #elseif canImport(UIKit)
        let fontAvailable = UIFont(name: interName, size: size) != nil
        #else
        let fontAvailable = false
        #endif

        if fontAvailable {
            return .custom(interName, size: size, relativeTo: style)
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
