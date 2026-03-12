import SwiftUI

// MARK: - AlertsListView

/// List of proactive financial alerts sorted by severity.
struct AlertsListView: View {
    @State var viewModel: AlertsViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading alerts...")
                Spacer()
            } else if viewModel.alerts.isEmpty {
                emptyState
            } else {
                alertList
            }
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.negative)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .background(WMColors.background)
        .task { await viewModel.loadAlerts() }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Image(systemName: "bell.badge")
                .foregroundStyle(WMColors.primary)
            Text("Alerts")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Spacer()
            if !viewModel.alerts.isEmpty {
                Text("\(viewModel.alerts.count)")
                    .font(WMTypography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(WMColors.negative)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var alertList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.alerts) { alert in
                    AlertRow(alert: alert)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.shield")
                .font(.system(size: 48))
                .foregroundStyle(WMColors.positive)
            Text("No alerts")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)
            Text("Your finances look healthy. Check back later.")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(24)
    }
}

// MARK: - AlertRow

private struct AlertRow: View {
    let alert: ProactiveAlertDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            severityBadge
            VStack(alignment: .leading, spacing: 4) {
                Text(alert.title)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textPrimary)
                Text(alert.message)
                    .font(WMTypography.caption)
                    .foregroundStyle(WMColors.textMuted)
            }
            Spacer()
        }
        .padding(14)
        .background(WMColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(severityColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var severityBadge: some View {
        Image(systemName: severityIcon)
            .font(.system(size: 20))
            .foregroundStyle(severityColor)
            .frame(width: 28)
    }

    private var severityIcon: String {
        switch alert.severity {
        case .action: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch alert.severity {
        case .action: return WMColors.negative
        case .warning: return Color.orange
        case .info: return WMColors.primary
        }
    }
}
