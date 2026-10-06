import PromiseKit
import Shared
import SwiftUI
import UIKit
import WebKit

// MARK: - WebView

extension WebViewController {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Deliberately does not mark disconnected: a navigation starting isn't a lost connection. Only the
        // frontend (via the external bus) or a hard reload (`reload()`/`refresh()`) sets disconnected.
        overlayState?.isLoading = true
        didHandleServerErrorResponse = false
        didReceiveClientCertificateChallenge = false
        webViewExternalMessageHandler.stopImprovScanIfNeeded()
        forgetOnscreenEntity()
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            // Remembered so a TLS failure or proxy refusal behind it is reported as a certificate problem.
            didReceiveClientCertificateChallenge = true
        }
        let result = server.info.connection.evaluate(challenge)
        completionHandler(result.0, result.1)
    }

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
            openURLInBrowser(url, self)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        overlayState?.isLoading = false
        if didHandleServerErrorResponse {
            didHandleServerErrorResponse = false
            return
        }
        if let err = error as? URLError {
            if err.code != .cancelled {
                Current.Log.error("Failure during nav: \(err)")
            }

            if !error.isCancelled {
                if Self.shouldRedirectToRootForNavigationError(error) {
                    redirectToActiveURLRoot(failedURL: (error as? URLError)?.failingURL ?? webView.url)
                    return
                }
                latestLoadError = error
                recordClientCertificateIssueIfNeeded(for: error)
                showEmptyState()
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        overlayState?.isLoading = false

        if didHandleServerErrorResponse {
            didHandleServerErrorResponse = false
            return
        }

        let nsError = error as NSError
        let shouldShowError: Bool

        // Handle URLError
        if let urlError = error as? URLError {
            shouldShowError = urlError.code != .cancelled
            if shouldShowError {
                Current.Log.error("Failure during content load: \(error)")
            }
        }
        // Handle WebKitErrorDomain errors (e.g., Code 101 - invalid URL)
        else if nsError.domain == "WebKitErrorDomain" {
            shouldShowError = !nsError.isCancelled
            Current.Log.error("WebKit error during content load: \(error)")
        } else {
            shouldShowError = !error.isCancelled
            if shouldShowError {
                Current.Log.error("Failure during content load: \(error)")
            }
        }

        if shouldShowError {
            if Self.shouldRedirectToRootForNavigationError(error) {
                redirectToActiveURLRoot(failedURL: (error as? URLError)?.failingURL ?? webView.url)
                return
            }
            latestLoadError = error
            recordClientCertificateIssueIfNeeded(for: error)
            showEmptyState()
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        handleContentProcessTermination()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        overlayState?.isLoading = false
        latestLoadError = nil
        // A page that loaded got through the handshake, so whatever certificate problem there was is gone.
        clientCertificateIssue = nil

        // in case the view appears again, don't reload
        initialURL = nil

        updateWebViewSettings(reason: .load)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        if #available(iOS 17.0, *) {
            let viewModel = DownloadManagerViewModel()
            download.delegate = viewModel
            // Present via `ContainerView`'s sheet (SwiftUI) instead of a UIKit overlay; the same view model
            // instance must back the sheet and the download delegate.
            Current.sceneManager.appCoordinator.done { $0.showDownloadManager(viewModel) }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        lastNavigationWasServerError = false

        guard navigationResponse.isForMainFrame else {
            // we don't need to modify the response if it's for a sub-frame
            decisionHandler(.allow)
            return
        }

        guard let httpResponse = navigationResponse.response as? HTTPURLResponse, httpResponse.statusCode >= 400 else {
            // not an error response, we don't need to inspect at all
            decisionHandler(.allow)
            return
        }

        lastNavigationWasServerError = true

        let cfMitigated = httpResponse.value(forHTTPHeaderField: "cf-mitigated")
        let cfRay = httpResponse.value(forHTTPHeaderField: "cf-ray") ?? "-"
        Current.Log.error(
            "Main frame HTTP \(httpResponse.statusCode) at \(navigationResponse.response.url?.absoluteString ?? "?"), cf-ray=\(cfRay), cf-mitigated=\(cfMitigated ?? "-")"
        )

        // A proxy refusing the request over the client certificate gets no navigation error, only this
        // response, so it is the one place the certificate empty state can come from.
        if handleClientCertificateRefusalIfNeeded(
            statusCode: httpResponse.statusCode,
            responseURL: navigationResponse.response.url,
            decisionHandler: decisionHandler
        ) {
            return
        }

        switch Self.decisionForMainFrameErrorResponse(
            statusCode: httpResponse.statusCode,
            responseURL: navigationResponse.response.url,
            initialURL: initialURL,
            cfMitigated: cfMitigated
        ) {
        case .allow:
            decisionHandler(.allow)
        case .redirectToRoot:
            // Don't render the server's 404/403; send the user home to the frontend root instead.
            decisionHandler(.cancel)
            redirectToActiveURLRoot(failedURL: navigationResponse.response.url)
        case .reloadDefaultURL:
            // first: clear that saved url, it's bad
            initialURL = nil

            // it's for the restored page, let's load the default url
            Task { [weak self] in
                if let self, let webviewURL = await server.webviewURL() {
                    decisionHandler(.cancel)
                    load(request: URLRequest(url: webviewURL))
                } else {
                    // we don't have anything we can do about this
                    decisionHandler(.allow)
                }
            }
        case .showEmptyState:
            didHandleServerErrorResponse = true
            decisionHandler(.cancel)
            latestLoadError = Self.serverErrorLoadError(for: navigationResponse.response.url)
            connectionState = Self.connectionStateForInterceptedServerError(current: connectionState)
            showEmptyState()
        }
    }

    // WKUIDelegate
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Without a touch to tell us where, an action sheet in the middle of a wide window isn't great:
        // compact widths get the bottom action sheet, everything else a centered alert.
        let style: UIAlertController.Style = webView.traitCollection.horizontalSizeClass == .compact
            ? .actionSheet
            : .alert

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: style)

        // iPad presents an unanchored action sheet as a popover and traps without location information,
        // even in a compact-width window — anchor it to the web view, arrowless, as a backstop.
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = webView
            popover.sourceRect = CGRect(x: webView.bounds.midX, y: webView.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.ok, style: .default, handler: { _ in
            completionHandler(true)
        }))

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { _ in
            completionHandler(false)
        }))

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler(false)
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

        alertController.addTextField { textField in
            textField.text = defaultText
        }

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Prompt.ok, style: .default, handler: { _ in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Prompt.cancel, style: .cancel, handler: { _ in
            completionHandler(nil)
        }))

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler(nil)
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        alertController.addAction(UIAlertAction(title: L10n.Alerts.Alert.ok, style: .default, handler: { _ in
            completionHandler()
        }))

        alertController.popoverPresentationController?.sourceView = self.webView

        if presentedViewController != nil {
            Current.Log.error("attempted to present an alert when already presenting, bailing")
            completionHandler()
        } else {
            present(alertController, animated: true, completion: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }
}

extension WebViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

extension WebViewController {
    enum MainFrameErrorResponseDecision: Equatable {
        case allow
        case reloadDefaultURL
        case redirectToRoot
        case showEmptyState
    }

    /// Client-error codes that mean "the page you asked for isn't there or isn't allowed" — a stale or
    /// hand-crafted deeplink, a dashboard that was removed, a forbidden path. These are dead ends, so the
    /// user is sent back to the frontend root instead of being left on the server's bare error page.
    /// Authentication (401) and rate-limit (429) responses are deliberately excluded: they keep rendering
    /// so an expired session still re-authenticates and a throttled server is not hammered with reloads.
    static let redirectToRootStatusCodes: Set<Int> = [403, 404, 410]

    static func decisionForMainFrameErrorResponse(
        statusCode: Int,
        responseURL: URL?,
        initialURL: URL?,
        cfMitigated: String?
    ) -> MainFrameErrorResponseDecision {
        if let initialURL, responseURL == initialURL {
            return .reloadDefaultURL
        }
        if cfMitigated?.lowercased() == "challenge" {
            return .allow
        }
        if statusCode >= 500 {
            return .showEmptyState
        }
        if redirectToRootStatusCodes.contains(statusCode) {
            return .redirectToRoot
        }
        return .allow
    }

    /// Whether a failed navigation should bounce the web view back to the frontend root rather than show
    /// the disconnected empty state. True only when the URL itself was the problem — a malformed or
    /// unsupported deeplink target — never for connectivity failures: the root lives on the same host, so
    /// redirecting on a lost or refused connection would just loop into the same failure.
    static func shouldRedirectToRootForNavigationError(_ error: Error) -> Bool {
        if error.isCancelled {
            return false
        }
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            return nsError.code == NSURLErrorBadURL || nsError.code == NSURLErrorUnsupportedURL
        case "WebKitErrorDomain":
            // 101 = WebKitErrorCannotShowURL: the URL is unsupported or malformed, not a reachability
            // problem, so the root (a well-formed URL) is a safe place to land.
            return nsError.code == 101
        default:
            return false
        }
    }

    static func connectionStateForInterceptedServerError(
        current: FrontEndConnectionState
    ) -> FrontEndConnectionState {
        current == .authInvalid ? .authInvalid : .disconnected
    }

    static func serverErrorLoadError(for url: URL?) -> URLError {
        guard let url else { return URLError(.badServerResponse) }
        return URLError(.badServerResponse, userInfo: [
            NSURLErrorFailingURLErrorKey: url,
            NSURLErrorFailingURLStringErrorKey: url.absoluteString,
        ])
    }
}
