import SwiftUI

/// AI insight card with frosted glass styling and a cyan orb accent.
struct AIInsightCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cyan orb icon
            Circle()
                .fill(
                    RadialGradient(
                        colors: [WMColors.secondary, WMColors.secondary.opacity(0.3)],
                        center: .center,
                        startRadius: 2,
                        endRadius: 14
                    )
                )
                .frame(width: 28, height: 28)
                .shadow(color: WMColors.secondary.opacity(0.5), radius: 8)

            Text(message)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI Insight: \(message)")
    }
}

/// Glass-styled button with optional SF Symbol icon.
struct GlassButton: View {
    let label: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(label)
                    .font(WMTypography.body)
            }
            .foregroundStyle(WMColors.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 10)
        }
        .buttonStyle(.plain)
    }
}

/// Small pill-shaped glass element for filters and tags.
struct GlassPill: View {
    let text: String
    var isSelected: Bool = false

    var body: some View {
        Text(text)
            .font(WMTypography.caption)
            .foregroundStyle(isSelected ? WMColors.primary : WMColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? WMColors.primary.opacity(0.15)
                    : WMColors.glassBg
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? WMColors.primary.opacity(0.4) : WMColors.glassBorder,
                        lineWidth: 1
                    )
            )
    }
}
