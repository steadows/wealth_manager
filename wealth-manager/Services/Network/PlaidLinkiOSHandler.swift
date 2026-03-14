#if os(iOS)
import Foundation
import os
import UIKit
import LinkKit

// MARK: - PlaidLinkiOSContinuationHandler

/// A refined iOS Plaid Link handler that uses continuations for async/await.
/// This handler creates the LinkKit configuration with callbacks that resolve
/// a continuation, enabling clean async/await integration.
///
/// Uses a thread-safe guard to prevent double continuation resume if the
/// Plaid SDK fires both onSuccess and onExit callbacks.
final class PlaidLinkiOSContinuationHandler: PlaidLinkHandlerProtocol, @unchecked Sendable {

    // MARK: - State

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wealthmanager",
        category: "PlaidLink"
    )

    private var linkToken: String?
    private(set) var isReady: Bool = false

    /// Thread-safe guard to ensure the continuation is resumed at most once.
    private let continuationLock = NSLock()
    private var continuationResumed = false

    // MARK: - Prepare

    /// Validates and stores the link token for later use in `open()`.
    /// - Parameter linkToken: The link token from the backend.
    /// - Throws: `PlaidLinkError.invalidLinkToken` if the token is empty.
    func prepare(linkToken: String) async throws {
        guard !linkToken.isEmpty else {
            throw PlaidLinkError.invalidLinkToken
        }

        self.linkToken = linkToken
        isReady = true
    }

    // MARK: - Open

    /// Creates the LinkKit handler with continuation-based callbacks,
    /// then presents the native Plaid Link UI.
    /// - Returns: A `PlaidLinkResult` indicating success, exit, or failure.
    func open() async -> PlaidLinkResult {
        guard let linkToken, isReady else {
            return .failure(PlaidLinkError.notPrepared)
        }

        // Reset the guard for each open() call
        continuationLock.lock()
        continuationResumed = false
        continuationLock.unlock()

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                /// Resumes the continuation at most once. Subsequent calls are ignored
                /// with a logged warning, preventing a crash if the Plaid SDK fires
                /// both onSuccess and onExit.
                func resumeOnce(returning value: PlaidLinkResult) {
                    guard let self else { return }
                    self.continuationLock.lock()
                    let alreadyResumed = self.continuationResumed
                    if !alreadyResumed {
                        self.continuationResumed = true
                    }
                    self.continuationLock.unlock()

                    if alreadyResumed {
                        Self.logger.warning("Plaid Link continuation already resumed — ignoring duplicate callback")
                        return
                    }
                    continuation.resume(returning: value)
                }

                var config = LinkTokenConfiguration(token: linkToken) { success in
                    let publicToken = success.publicToken
                    let institutionName = success.metadata.institution.name
                    resumeOnce(returning: .success(
                        publicToken: publicToken,
                        institutionName: institutionName
                    ))
                }

                config.onExit = { exit in
                    let errorMessage = exit.error?.localizedDescription
                    resumeOnce(returning: .exit(errorMessage: errorMessage))
                }

                let result = Plaid.create(config)
                switch result {
                case .success(let handler):
                    guard let presentingVC = self?.findPresentingViewController() else {
                        resumeOnce(returning: .failure(
                            PlaidLinkError.sdkInitializationFailed(
                                "No presenting view controller found"
                            )
                        ))
                        return
                    }
                    handler.open(presentUsing: .viewController(presentingVC))

                case .failure(let error):
                    resumeOnce(returning: .failure(
                        PlaidLinkError.sdkInitializationFailed(error.localizedDescription)
                    ))
                }
            }
        }
    }

    // MARK: - Private

    /// Finds the topmost view controller for presenting Plaid Link.
    private func findPresentingViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              var topController = window.rootViewController else {
            return nil
        }

        while let presented = topController.presentedViewController {
            topController = presented
        }

        return topController
    }
}
#endif
