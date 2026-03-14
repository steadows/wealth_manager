import SwiftUI

/// Generic empty state view with icon, title, description, and optional action button.
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var actionLabel: String?
    var action: (() -> Void)?

    /// Primary initializer using `actionLabel`.
    init(
        icon: String,
        title: String,
        description: String,
        actionLabel: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionLabel = actionLabel
        self.action = action
    }

    /// Convenience initializer accepting `actionTitle` (used by some existing views).
    init(
        icon: String,
        title: String,
        description: String,
        actionTitle: String?,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.actionLabel = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(WMColors.textMuted)

            Text(title)
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text(description)
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionLabel, let action {
                GlassButton(label: actionLabel, action: action)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}
