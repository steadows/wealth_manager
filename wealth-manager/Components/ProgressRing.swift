import SwiftUI

/// Circular progress indicator with gradient stroke.
struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6
    var threshold: Double = 1.0

    var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(WMColors.glassBorder, lineWidth: lineWidth)

            // Progress arc
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    strokeGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage label
            Text(percentageLabel)
                .font(.system(size: size * 0.22, weight: .medium, design: .rounded))
                .foregroundStyle(isOverThreshold ? WMColors.negative : WMColors.textPrimary)
        }
        .frame(width: size, height: size)
    }

    // MARK: - Private

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var isOverThreshold: Bool {
        progress > threshold
    }

    private var strokeGradient: some ShapeStyle {
        if isOverThreshold {
            return AngularGradient(
                colors: [WMColors.negative, WMColors.negative.opacity(0.7)],
                center: .center
            )
        }
        return AngularGradient(
            colors: [WMColors.primary, WMColors.secondary],
            center: .center
        )
    }

    private var percentageLabel: String {
        let percent = Int((progress * 100).rounded())
        return "\(percent)%"
    }
}
