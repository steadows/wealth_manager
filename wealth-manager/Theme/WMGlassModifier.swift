import SwiftUI

/// A frosted glass card modifier following the Holographic JARVIS design system.
struct GlassCardModifier: ViewModifier {

    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(WMColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(WMColors.glassBorder, lineWidth: 1)
            )
            .shadow(
                color: WMColors.primary.opacity(0.08),
                radius: 12,
                x: 0,
                y: 4
            )
    }
}

extension View {
    /// Applies frosted glass card styling with optional corner radius.
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
}
