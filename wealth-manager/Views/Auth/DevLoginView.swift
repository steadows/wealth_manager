#if DEBUG
import SwiftUI

// MARK: - DevLoginView

/// Developer-only sign-in screen for local/sandbox authentication.
/// Shown when the app is not authenticated and built in DEBUG mode.
struct DevLoginView: View {
    @Bindable var viewModel: DevLoginViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            headerSection

            backendStatusSection

            signInButton

            if let error = viewModel.error {
                errorBanner(error)
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WMColors.background)
        .task {
            await viewModel.checkBackendHealth()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 48))
                .foregroundStyle(WMColors.tertiary)

            Text("Dev Sign In")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Local development mode")
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
    }

    private var backendStatusSection: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(backendStatusColor)
                .frame(width: 10, height: 10)

            Text(backendStatusText)
                .font(WMTypography.caption)
                .foregroundStyle(WMColors.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(WMColors.glassBg)
        .clipShape(Capsule())
    }

    private var signInButton: some View {
        Button {
            Task {
                await viewModel.signIn()
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: 200)
            } else {
                Text("Dev Sign In")
                    .font(WMTypography.body)
                    .frame(maxWidth: 200)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(WMColors.primary)
        .disabled(viewModel.isLoading)
        .accessibilityLabel("Sign in as development user")
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(WMTypography.caption)
            .foregroundStyle(WMColors.negative)
            .padding(12)
            .frame(maxWidth: 400)
            .background(WMColors.negative.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Computed Properties

    private var backendStatusColor: Color {
        switch viewModel.isBackendReachable {
        case .some(true): WMColors.positive
        case .some(false): WMColors.negative
        case .none: WMColors.textMuted
        }
    }

    private var backendStatusText: String {
        switch viewModel.isBackendReachable {
        case .some(true): "Backend connected"
        case .some(false): "Backend unreachable"
        case .none: "Checking backend..."
        }
    }
}
#endif
