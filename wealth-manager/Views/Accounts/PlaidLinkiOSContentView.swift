#if os(iOS)
import SwiftUI

// MARK: - PlaidLinkiOSContentView

/// SwiftUI view that manages the native Plaid Link iOS flow.
///
/// Prepares the handler with the link token, then automatically opens
/// the native Plaid Link UI. Shows a loading indicator while preparing
/// and an error state if preparation fails.
struct PlaidLinkiOSContentView: View {

    /// The link token obtained from the backend.
    let linkToken: String

    /// The Plaid Link handler (injected for testability).
    let handler: PlaidLinkHandlerProtocol?

    /// Called with the result of the Plaid Link flow.
    var onResult: (PlaidLinkResult) -> Void

    /// Called when the user exits without completing.
    var onExit: () -> Void

    // MARK: - State

    @State private var isPreparing = true
    @State private var prepareError: String?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            if isPreparing {
                ProgressView("Initializing Plaid Link...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let prepareError {
                errorView(message: prepareError)
            } else {
                // Handler is prepared and will present native UI
                ProgressView("Opening Plaid Link...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await prepareLinkHandler()
        }
    }

    // MARK: - Private

    private func prepareLinkHandler() async {
        guard let handler else {
            isPreparing = false
            prepareError = "Plaid Link is not configured."
            return
        }

        do {
            try await handler.prepare(linkToken: linkToken)
            isPreparing = false

            // Open the native Plaid Link UI
            let result = await handler.open()
            onResult(result)
        } catch {
            isPreparing = false
            prepareError = error.localizedDescription
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Plaid Link Error")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Back") {
                onExit()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
