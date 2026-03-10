import SwiftUI
import WebKit

// MARK: - PlaidLinkWebView

/// SwiftUI wrapper around WKWebView for hosting the Plaid Link flow.
/// Intercepts JavaScript postMessage callbacks from Plaid to handle
/// success, exit, and event notifications.
struct PlaidLinkWebView: NSViewRepresentable {

    /// The Plaid Link URL to load (includes the link token).
    let url: URL

    /// Called when Plaid Link completes successfully with a public token.
    var onSuccess: (String, [String: Any]) -> Void

    /// Called when the user exits Plaid Link without completing.
    var onExit: ((String?, [String: Any]) -> Void)?

    /// Called for Plaid Link events (optional telemetry hook).
    var onEvent: ((String, [String: Any]) -> Void)?

    // MARK: - Message Handler Names

    private static let successHandler = "plaidLinkSuccess"
    private static let exitHandler = "plaidLinkExit"
    private static let eventHandler = "plaidLinkEvent"

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = config.userContentController

        // Register JS message handlers
        controller.add(context.coordinator, name: Self.successHandler)
        controller.add(context.coordinator, name: Self.exitHandler)
        controller.add(context.coordinator, name: Self.eventHandler)

        // Inject JS bridge to forward Plaid postMessage to native handlers
        let bridgeScript = Self.buildBridgeScript()
        controller.addUserScript(bridgeScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Only reload if the URL changed
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSuccess: onSuccess,
            onExit: onExit,
            onEvent: onEvent
        )
    }

    // MARK: - JS Bridge

    /// Builds a user script that intercepts Plaid Link's postMessage events
    /// and routes them to the appropriate native message handler.
    private static func buildBridgeScript() -> WKUserScript {
        let source = """
        window.addEventListener('message', function(event) {
            var data = event.data;
            if (typeof data === 'string') {
                try { data = JSON.parse(data); } catch(e) { return; }
            }
            if (!data || !data.action) { return; }

            if (data.action === 'connected') {
                var payload = {
                    publicToken: data.public_token || '',
                    metadata: data.metadata || {}
                };
                window.webkit.messageHandlers.\(successHandler).postMessage(payload);
            } else if (data.action === 'exit') {
                var exitPayload = {
                    error: data.error || null,
                    metadata: data.metadata || {}
                };
                window.webkit.messageHandlers.\(exitHandler).postMessage(exitPayload);
            } else {
                var eventPayload = {
                    eventName: data.action,
                    metadata: data.metadata || {}
                };
                window.webkit.messageHandlers.\(eventHandler).postMessage(eventPayload);
            }
        }, false);
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

        let onSuccess: (String, [String: Any]) -> Void
        let onExit: ((String?, [String: Any]) -> Void)?
        let onEvent: ((String, [String: Any]) -> Void)?

        init(
            onSuccess: @escaping (String, [String: Any]) -> Void,
            onExit: ((String?, [String: Any]) -> Void)?,
            onEvent: ((String, [String: Any]) -> Void)?
        ) {
            self.onSuccess = onSuccess
            self.onExit = onExit
            self.onEvent = onEvent
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any] else { return }

            switch message.name {
            case PlaidLinkWebView.successHandler:
                handleSuccess(body)
            case PlaidLinkWebView.exitHandler:
                handleExit(body)
            case PlaidLinkWebView.eventHandler:
                handleEvent(body)
            default:
                break
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow all navigation within Plaid Link
            decisionHandler(.allow)
        }

        // MARK: - Private

        private func handleSuccess(_ body: [String: Any]) {
            let publicToken = body["publicToken"] as? String ?? ""
            let metadata = body["metadata"] as? [String: Any] ?? [:]
            onSuccess(publicToken, metadata)
        }

        private func handleExit(_ body: [String: Any]) {
            let errorMessage = body["error"] as? String
            let metadata = body["metadata"] as? [String: Any] ?? [:]
            onExit?(errorMessage, metadata)
        }

        private func handleEvent(_ body: [String: Any]) {
            let eventName = body["eventName"] as? String ?? "unknown"
            let metadata = body["metadata"] as? [String: Any] ?? [:]
            onEvent?(eventName, metadata)
        }
    }
}
