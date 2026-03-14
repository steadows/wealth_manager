import SwiftUI

// MARK: - RootView

/// Top-level view that gates on authentication state.
/// In DEBUG builds, shows DevLoginView when not authenticated.
/// In release builds, shows a placeholder sign-in message (Apple Sign In is future work).
struct RootView: View {
    #if DEBUG
    @State private var devLoginVM: DevLoginViewModel
    #endif

    private let tokenStore: KeychainTokenStore
    private let apiClient: APIClient
    private let authService: AuthService

    /// Tracks whether the user has signed in during this session.
    /// Updated by DevLoginView's onChange when `isSignedIn` flips to true.
    @State private var didSignIn: Bool = false

    init() {
        let backendURL = AppEnvironment.backendBaseURL
        let store = KeychainTokenStore()
        let bootstrapProvider = StoredTokenProvider(store: store)
        let client = APIClient(baseURL: backendURL, tokenProvider: bootstrapProvider)
        let service = AuthService(apiClient: client, tokenStore: store)

        self.tokenStore = store
        self.apiClient = client
        self.authService = service

        #if DEBUG
        _devLoginVM = State(initialValue: DevLoginViewModel(
            authService: service,
            healthAPIClient: client
        ))
        #endif
    }

    var body: some View {
        Group {
            if authService.isAuthenticated || didSignIn {
                #if os(macOS)
                MainSplitView()
                #else
                MainTabView()
                #endif
            } else {
                #if DEBUG
                DevLoginView(viewModel: devLoginVM)
                    .onChange(of: devLoginVM.isSignedIn) { _, signedIn in
                        if signedIn {
                            didSignIn = true
                        }
                    }
                #else
                signInRequiredView
                #endif
            }
        }
    }

    // MARK: - Production Placeholder

    private var signInRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield")
                .font(.system(size: 48))
                .foregroundStyle(WMColors.textMuted)

            Text("Sign in required")
                .font(WMTypography.heading)
                .foregroundStyle(WMColors.textPrimary)

            Text("Apple Sign In coming soon")
                .font(WMTypography.body)
                .foregroundStyle(WMColors.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WMColors.background)
    }
}
