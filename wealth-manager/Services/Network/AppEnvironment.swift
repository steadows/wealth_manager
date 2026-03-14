import Foundation
import os

// MARK: - AppEnvironment

/// Configures the backend base URL based on build configuration and runtime overrides.
/// Supports development, staging, and production environments.
///
/// Resolution order:
/// 1. `WM_BASE_URL` environment variable (for testing/CI)
/// 2. `BackendBaseURL` key in Info.plist (set via Xcode build configuration)
/// 3. Compile-time default based on `DEBUG` flag
enum AppEnvironment {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wealthmanager",
        category: "AppEnvironment"
    )

    /// The resolved backend base URL.
    ///
    /// Checks environment variables and Info.plist before falling back to
    /// compile-time defaults. In release builds, validates that the URL
    /// uses HTTPS to prevent accidental insecure connections.
    static let backendBaseURL: URL = {
        // 1. Environment variable override (useful for tests and CI)
        if let envURL = ProcessInfo.processInfo.environment["WM_BASE_URL"],
           let url = URL(string: envURL) {
            return validateScheme(url)
        }

        // 2. Info.plist key (set per build configuration in Xcode)
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
           !plistURL.isEmpty,
           let url = URL(string: plistURL) {
            return validateScheme(url)
        }

        // 3. Compile-time default
        #if DEBUG
        return URL(string: "http://localhost:8000")!
        #else
        return URL(string: "https://api.wealthmanager.app")!
        #endif
    }()

    /// Validates that the URL uses HTTPS in release builds.
    /// In DEBUG builds, HTTP is allowed for local development.
    private static func validateScheme(_ url: URL) -> URL {
        #if DEBUG
        if url.scheme == "http" {
            logger.info("Using HTTP backend URL in DEBUG: \(url.absoluteString, privacy: .public)")
        }
        return url
        #else
        guard url.scheme == "https" else {
            logger.error(
                "Non-HTTPS backend URL rejected in release build: \(url.absoluteString, privacy: .public). Falling back to production URL."
            )
            return URL(string: "https://api.wealthmanager.app")!
        }
        return url
        #endif
    }

    /// Human-readable name for the current environment (for logging/diagnostics).
    static var environmentName: String {
        if ProcessInfo.processInfo.environment["WM_BASE_URL"] != nil {
            return "custom"
        }
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String,
           !plistURL.isEmpty {
            if plistURL.contains("staging") { return "staging" }
            if plistURL.contains("localhost") { return "development" }
            return "production"
        }
        #if DEBUG
        return "development"
        #else
        return "production"
        #endif
    }
}
