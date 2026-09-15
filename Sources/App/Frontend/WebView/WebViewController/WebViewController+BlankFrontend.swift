import Shared
import UIKit
@preconcurrency import WebKit

// MARK: - Blank Frontend Detection & Recovery

extension WebViewController {
    static let blankPageURLString = "about:blank"
    static let maximumBlankFrontendRecoveryAttempts = 1

    func hasRenderedFrontend() async -> Bool {
        if let hasRenderedFrontendCheck {
            return await withCheckedContinuation { continuation in
                hasRenderedFrontendCheck { continuation.resume(returning: $0) }
            }
        }

        guard let webView, let url = webView.url, url.absoluteString != Self.blankPageURLString else {
            return false
        }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(WebViewJavascriptCommands.frontendRenderedProbe) { result, error in
                continuation.resume(returning: Self.hasRenderedFrontend(probeResult: result, error: error))
            }
        }
    }

    /// Non-private for tests.
    static func hasRenderedFrontend(probeResult: Any?, error: Error?) -> Bool {
        if let error {
            Current.Log.error("Frontend render probe failed: \(error)")
            return false
        }
        return probeResult as? Bool ?? false
    }

    @discardableResult
    func recoverFromBlankFrontend() -> Bool {
        guard blankFrontendRecoveryAttempts < Self.maximumBlankFrontendRecoveryAttempts else {
            Current.Log.error("""
            Frontend still rendered nothing after recovery, \
            giving up on \(server.identifier.rawValue)
            """)
            return false
        }
        blankFrontendRecoveryAttempts += 1

        if isShowingRestoredPath {
            Current.Log.error("Restored path \(initialURLPath ?? "") rendered nothing, loading the frontend root")
            forgetRestoredPath()
            navigateToRoot()
        } else {
            Current.Log.error("Frontend rendered nothing, cleaning its cache and reloading")
            Current.websiteDataStoreHandler.cleanCache(
                dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes
            ) { [weak self] in
                self?.reload()
            }
        }
        return true
    }

    func handleContentProcessTermination() {
        guard overlayState?.showsNoActiveURL != true else {
            Current.Log.error("Web content process terminated behind the no-active-URL state, leaving it alone")
            return
        }

        contentProcessTerminations += 1
        Current.Log.error("""
        Web content process terminated for \(server.identifier.rawValue), \
        termination \(contentProcessTerminations)
        """)
        overlayState?.isLoading = false

        switch contentProcessTerminations {
        case 1:
            if webView?.url == nil {
                loadActiveURLIfNeeded()
            } else {
                reload()
            }
        case 2:
            if !recoverFromBlankFrontend() {
                showBlankFrontendEmptyState()
            }
        default:
            showBlankFrontendEmptyState()
        }
    }

    func showBlankFrontendEmptyState() {
        connectionState = .disconnected
        overlayState?.connectionState = .disconnected
        showEmptyState()
    }

    func resetBlankFrontendRecovery() {
        blankFrontendRecoveryAttempts = 0
        contentProcessTerminations = 0
    }

    func resetBlankFrontendRecoveryIfRendered(for state: FrontEndConnectionState) {
        guard state == .loaded || server.info.version < .frontendLoadedExternalBus else { return }
        resetBlankFrontendRecovery()
    }

    /// Non-private for tests.
    static func isShowingRestoredPath(restoredPath: String?, currentPath: String?) -> Bool {
        guard let restoredPath, let currentPath else { return false }
        return URLComponents(string: restoredPath)?.path == currentPath
    }

    private var isShowingRestoredPath: Bool {
        Self.isShowingRestoredPath(restoredPath: initialURLPath, currentPath: webView?.url?.path)
    }

    /// Non-private for tests.
    func forgetRestoredPath() {
        initialURLPath = nil
        initialURL = nil
        guard Current.settingsStore.lastActiveServerIdentifier == server.identifier.rawValue else { return }
        Current.settingsStore.lastActiveURLPath = nil
    }
}
