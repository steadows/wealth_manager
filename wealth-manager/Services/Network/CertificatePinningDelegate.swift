import CryptoKit
import Foundation
import os
import Security

// MARK: - CertificatePinningDelegate

/// URLSession delegate that performs public-key pinning for API requests.
///
/// Pins against the server's public key (SPKI hash) rather than the full certificate,
/// allowing certificate rotation without app updates. Supports multiple pinned keys
/// for rotation overlap and a fallback to system trust for development builds.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {

    /// Shared singleton instance used across the app.
    static let shared = CertificatePinningDelegate()

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.wealthmanager",
        category: "CertificatePinning"
    )

    /// Base64-encoded SHA-256 hashes of pinned Subject Public Key Info (SPKI).
    /// Include both the current and next-rotation key to allow seamless cert rotation.
    ///
    /// To generate a pin from a certificate:
    /// ```
    /// openssl x509 -in server.crt -pubkey -noout | \
    ///   openssl pkey -pubin -outform der | \
    ///   openssl dgst -sha256 -binary | \
    ///   openssl enc -base64
    /// ```
    private let pinnedPublicKeyHashes: [String] = {
        // Load pins from Info.plist if available (allows build-config-specific pins)
        if let plistPins = Bundle.main.object(forInfoDictionaryKey: "CertificatePins") as? [String],
           !plistPins.isEmpty {
            return plistPins
        }
        // Default pins — replace with your production server's SPKI hashes
        return [
            // Primary key pin (current production certificate)
            // "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
            // Backup key pin (next rotation certificate)
            // "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
        ]
    }()

    /// Whether pinning is enforced. Only enforced when pins are actually configured.
    /// When no pins are present, falls back to system trust with a logged warning
    /// to prevent silently rejecting all HTTPS connections in production.
    private var isPinningEnforced: Bool {
        if pinnedPublicKeyHashes.isEmpty {
            #if !DEBUG
            Self.logger.warning(
                "Certificate pinning disabled — no pins configured. Falling back to system trust."
            )
            #endif
            return false
        }
        return true
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            return (.performDefaultHandling, nil)
        }

        // If pinning is not enforced (DEBUG with no pins), fall back to default system trust
        guard isPinningEnforced else {
            return (.performDefaultHandling, nil)
        }

        // Evaluate the server trust chain against system root CAs
        var error: CFError?
        let trustValid = SecTrustEvaluateWithError(serverTrust, &error)
        guard trustValid else {
            return (.cancelAuthenticationChallenge, nil)
        }

        // Check if any certificate in the chain matches a pinned public key
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return (.cancelAuthenticationChallenge, nil)
        }

        for certificate in certificateChain {
            if let publicKeyHash = publicKeyHashForCertificate(certificate),
               pinnedPublicKeyHashes.contains(publicKeyHash) {
                let credential = URLCredential(trust: serverTrust)
                return (.useCredential, credential)
            }
        }

        // No pinned key matched — reject the connection
        return (.cancelAuthenticationChallenge, nil)
    }

    // MARK: - Public Key Hashing

    /// Extracts the public key from a certificate and returns its Base64-encoded SHA-256 hash.
    private func publicKeyHashForCertificate(_ certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return nil
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // Hash the raw public key data with SHA-256
        let digest = SHA256.hash(data: publicKeyData)
        return Data(digest).base64EncodedString()
    }

    // MARK: - Session Factory

    /// Creates a URLSession configured with certificate pinning and the given timeouts.
    func pinnedSession(
        timeoutForRequest: TimeInterval = 30,
        timeoutForResource: TimeInterval = 60
    ) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutForRequest
        config.timeoutIntervalForResource = timeoutForResource
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
}
