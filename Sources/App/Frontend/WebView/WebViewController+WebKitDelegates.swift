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
        webViewExternalMessageHandler.stopImprovScanIfNeeded()
    }

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
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
        refreshControl.endRefreshing()
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
                latestLoadError = error
                showEmptyState()
            }
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        refreshControl.endRefreshing()
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
            latestLoadError = error
            showEmptyState()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        overlayState?.isLoading = false
        latestLoadError = nil

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

        switch Self.decisionForMainFrameErrorResponse(
            statusCode: httpResponse.statusCode,
            responseURL: navigationResponse.response.url,
            initialURL: initialURL,
            cfMitigated: cfMitigated
        ) {
        case .allow:
            decisionHandler(.allow)
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
        let style: UIAlertController.Style = {
            switch webView.traitCollection.userInterfaceIdiom {
            case .carPlay, .phone, .tv:
                return .actionSheet
            case .mac:
                return .alert
            case .pad, .unspecified, .vision:
                // without a touch to tell us where, an action sheet in the middle of the screen isn't great
                return .alert
            @unknown default:
                return .alert
            }
        }()

        let alertController = UIAlertController(title: nil, message: message, preferredStyle: style)

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
        case showEmptyState
    }

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
        guard statusCode >= 500 else {
            return .allow
        }
        return .showEmptyState
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
