import Shared
import UIKit
@preconcurrency import WebKit

// MARK: - Web View Configuration & Setup

enum WebViewKeyboardAvoidance {
    static func keyboardAnimationDuration(from notification: Notification) -> TimeInterval {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber else {
            return 0
        }

        return duration.doubleValue
    }

    static func keyboardAnimationOptions(from notification: Notification) -> UIView.AnimationOptions {
        guard let curve = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber else {
            return .curveEaseInOut
        }

        return UIView.AnimationOptions(rawValue: UInt(curve.uintValue << 16))
    }

    static func keyboardOverlapHeight(in view: UIView, notification: Notification) -> CGFloat {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return 0
        }

        return view.bounds.intersection(view.convert(keyboardFrame, from: nil)).height
    }
}

extension WKWebView {
    func scrollFocusedElementIntoView(logError: @escaping (Error) -> Void = { _ in }) {
        evaluateJavaScript(WebViewJavascriptCommands.scrollFocusedElementIntoView) { _, error in
            if let error {
                logError(error)
            }
        }
    }
}

extension WebViewController {
    static func makeWebViewBottomConstraint(for webView: WKWebView, in view: UIView) -> NSLayoutConstraint {
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    }

    func setupKeyboardAvoidance() {
        guard !Current.isCatalyst else { return }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    @objc private func handleKeyboardWillChangeFrame(_ notification: Notification) {
        updateWebViewBottomConstraint(using: notification)
        scheduleFocusedElementScroll(using: notification)
    }

    @objc private func handleKeyboardDidChangeFrame(_ notification: Notification) {
        guard WebViewKeyboardAvoidance.keyboardOverlapHeight(in: view, notification: notification) > 0 else { return }
        scrollFocusedElementIntoView()
    }

    func scheduleFocusedElementScroll(using notification: Notification) {
        let overlapHeight = WebViewKeyboardAvoidance.keyboardOverlapHeight(in: view, notification: notification)
        keyboardFocusedElementScrollWorkItem?.cancel()

        guard overlapHeight > 0 else {
            keyboardFocusedElementScrollWorkItem = nil
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.scrollFocusedElementIntoView()
        }
        keyboardFocusedElementScrollWorkItem = workItem

        let delay = WebViewKeyboardAvoidance.keyboardAnimationDuration(from: notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func updateWebViewBottomConstraint(using notification: Notification) {
        let overlapHeight = WebViewKeyboardAvoidance.keyboardOverlapHeight(in: view, notification: notification)
        let duration = WebViewKeyboardAvoidance.keyboardAnimationDuration(from: notification)
        let options = WebViewKeyboardAvoidance.keyboardAnimationOptions(from: notification)

        webViewBottomConstraint?.constant = -overlapHeight

        UIView.animate(withDuration: duration, delay: 0, options: [options, .beginFromCurrentState]) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    private func scrollFocusedElementIntoView() {
        webView.scrollFocusedElementIntoView { error in
            Current.Log.error("Error scrolling focused element into view: \(error)")
        }
    }

    func setupUserContentController() -> WKUserContentController {
        let userContentController = WKUserContentController()
        let safeScriptMessageHandler = SafeScriptMessageHandler(server: server, delegate: webViewScriptMessageHandler)
        userContentController.add(safeScriptMessageHandler, name: "getExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "revokeExternalAuth")
        userContentController.add(safeScriptMessageHandler, name: "externalBus")
        userContentController.add(safeScriptMessageHandler, name: "updateThemeColors")
        userContentController.add(safeScriptMessageHandler, name: "logError")
        return userContentController
    }

    func setupWebViewConstraints(statusBarView: UIView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        webViewBottomConstraint = Self.makeWebViewBottomConstraint(for: webView, in: view)
        webViewBottomConstraint?.isActive = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Create the top constraint based on edge-to-edge setting
        // On iOS (not Catalyst), edge-to-edge mode pins the webview to the top of the view
        // On Catalyst, we always show the status bar buttons, so we pin to statusBarView
        // Also use edge-to-edge behavior when fullScreen is enabled (status bar hidden)
        let edgeToEdge = (Current.settingsStore.edgeToEdge || Current.settingsStore.fullScreen) && !Current.isCatalyst
        if edgeToEdge {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: view.topAnchor)
            statusBarView.isHidden = true
        } else {
            webViewTopConstraint = webView.topAnchor.constraint(equalTo: statusBarView.bottomAnchor)
            statusBarView.isHidden = false
        }
        webViewTopConstraint?.isActive = true
    }

    func setupURLObserver() {
        urlObserver = webView.observe(\.url) { [weak self] webView, _ in
            guard let self else { return }

            guard let currentURL = webView.url?.absoluteString.replacingOccurrences(of: "?external_auth=1", with: ""),
                  let cleanURL = URL(string: currentURL), let scheme = cleanURL.scheme else {
                return
            }

            guard ["http", "https"].contains(scheme) else {
                Current.Log.warning("Was going to provide invalid URL to NSUserActivity! \(currentURL)")
                return
            }

            userActivity?.webpageURL = cleanURL
            userActivity?.userInfo = [
                RestorableStateKey.lastURL.rawValue: cleanURL,
                RestorableStateKey.server.rawValue: server.identifier.rawValue,
            ]
            userActivity?.becomeCurrent()
        }
    }
}
