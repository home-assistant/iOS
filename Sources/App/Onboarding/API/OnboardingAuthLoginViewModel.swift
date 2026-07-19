import Foundation
import PromiseKit
import Shared
import WebKit

/// Owns the login `WKWebView` and resolves the OAuth callback for `OnboardingAuthLoginView`.
/// Replaces the UIKit `OnboardingAuthLoginViewController`; the hosting view renders `webView` and the
/// auth flow observes `resultPromise`.
final class OnboardingAuthLoginViewModel: NSObject, ObservableObject, Identifiable, WKNavigationDelegate,
    WKUIDelegate {
    enum LoginError: Error {
        case invalidURL
    }

    let authDetails: OnboardingAuthDetails
    let promise: Promise<URL>

    /// The server URL the web view actually ended up on (may differ in port/scheme from `authDetails.url`
    /// when the server issues a redirect during login). Set before `promise` is fulfilled.
    private(set) var resolvedServerURL: URL?

    /// True once the OAuth callback fulfilled the promise; the view covers the web view with a loading
    /// indicator while the rest of the auth flow (token exchange, registration) runs.
    @Published private(set) var didCompleteLogin = false

    /// The auth code extracted from the OAuth callback, together with `resolvedServerURL`.
    private(set) lazy var resultPromise: Promise<OnboardingAuthLoginResult> = promise
        .map { [weak self] url in
            if let code = url.queryItems?["code"] {
                return OnboardingAuthLoginResult(code: code, resolvedURL: self?.resolvedServerURL)
            } else {
                throw LoginError.invalidURL
            }
        }

    let webView: WKWebView

    private let resolver: Resolver<URL>
    private var lastNavigatedURL: URL?
    private var hasStartedLoading = false

    init(authDetails: OnboardingAuthDetails) {
        self.authDetails = authDetails
        (self.promise, self.resolver) = Promise<URL>.pending()

        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = HomeAssistantAPI.applicationNameForUserAgent
        configuration.defaultWebpagePreferences.preferredContentMode = Current.isCatalyst ? .desktop : .mobile
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isInspectable = true
    }

    /// Loads the login page on first appearance; later appearances keep the current page.
    func startIfNeeded() {
        guard !hasStartedLoading else { return }
        hasStartedLoading = true
        refresh()
    }

    func refresh() {
        webView.load(URLRequest(url: authDetails.url))
    }

    func cancel() {
        resolver.reject(PMKError.cancelled)
    }

    /// Called when the hosting view disappears; a dismissal without a resolved callback is a cancellation.
    func cancelIfUnresolved() {
        guard !promise.isResolved else { return }
        resolver.reject(PMKError.cancelled)
    }

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Handle client certificate challenge (mTLS)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            handleClientCertificateChallenge(challenge, completionHandler: completionHandler)
            return
        }

        // Handle server trust (including self-signed certs)
        let result = authDetails.exceptions.evaluate(challenge)
        completionHandler(result.0, result.1)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resolver.reject(error)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url, url.scheme?.hasPrefix("homeassistant") == true {
            // The web view may have been redirected to a different port/scheme during login; capture
            // where it actually ended up so the stored server URL reflects the real address.
            resolvedServerURL = webView.url ?? lastNavigatedURL
            didCompleteLogin = true
            resolver.fulfill(url)
            decisionHandler(.cancel)
        } else {
            if let url = navigationAction.request.url, url.scheme == "http" || url.scheme == "https" {
                lastNavigatedURL = url
            }
            decisionHandler(.allow)
        }
    }

    // MARK: - WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            guard let url = navigationAction.request.url else {
                Current.Log.error("Received navigation action without URL for new window")
                return nil
            }
            openURLInBrowser(url, nil)
        }
        return nil
    }

    private func handleClientCertificateChallenge(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        #if !os(watchOS)
        guard let clientCertificate = authDetails.clientCertificate else {
            Current.Log.error("Client certificate required but none configured")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        do {
            let credential = try ClientCertificateManager.shared.urlCredential(for: clientCertificate)
            Current.Log.info("Using client certificate: \(clientCertificate.displayName)")
            completionHandler(.useCredential, credential)
        } catch {
            Current.Log.error("Failed to get credential for client certificate: \(error)")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
        #else
        completionHandler(.cancelAuthenticationChallenge, nil)
        #endif
    }
}

#if DEBUG
extension OnboardingAuthLoginViewModel {
    var webViewForTests: WKWebView {
        webView
    }
}
#endif
