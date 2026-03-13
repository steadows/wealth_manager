import SwiftUI

// MARK: - AppLockView

/// Full-screen overlay presented when the app is locked.
/// Displays a biometric prompt button whose label adapts to Face ID or Touch ID.
struct AppLockView: View {
    @Bindable var viewModel: AppLockViewModel
    let biometryType: BiometryType

    var body: some View {
        ZStack {
            #if os(macOS)
            Color(.windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(.systemBackground)
                .ignoresSafeArea()
            #endif

            VStack(spacing: 24) {
                lockIcon
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text("Wealth Manager")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Locked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let error = viewModel.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button {
                    Task { await viewModel.authenticate() }
                } label: {
                    Label(biometricButtonTitle, systemImage: biometricSystemImage)
                        .frame(minWidth: 200)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isAuthenticating)

                if viewModel.isAuthenticating {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(40)
        }
    }

    // MARK: - Private Helpers

    private var lockIcon: some View {
        Image(systemName: "lock.fill")
    }

    private var biometricButtonTitle: String {
        switch biometryType {
        case .faceID:   return "Unlock with Face ID"
        case .touchID:  return "Unlock with Touch ID"
        case .none:     return "Unlock"
        }
    }

    private var biometricSystemImage: String {
        switch biometryType {
        case .faceID:   return "faceid"
        case .touchID:  return "touchid"
        case .none:     return "lock.open.fill"
        }
    }
}
