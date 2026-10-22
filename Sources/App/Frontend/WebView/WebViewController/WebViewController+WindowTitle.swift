import Combine
import Shared
import UIKit

// MARK: - Window Title

extension WebViewController {
    private static let frontendTitleSuffixes = [" – Home Assistant", " - Home Assistant"]

    func setupWindowTitleObserver() {
        windowTitleObserver = webView.observe(\.title) { [weak self] _, _ in
            self?.updateWindowSceneTitle()
            // The same title names the page on the user activity, and a frontend route change sets it
            // a beat after the URL it belongs to.
            self?.updateOnscreenContent()
        }
    }

    func observeEmptyStateForWindowTitle() {
        emptyStateTitleObserver = overlayState?.$emptyState.sink { [weak self] emptyState in
            self?.updateWindowSceneTitle(isCoveredByEmptyState: emptyState != nil)
        }
    }

    func updateWindowSceneTitle() {
        updateWindowSceneTitle(isCoveredByEmptyState: overlayState?.emptyState != nil)
    }

    /// `viewIfLoaded` so that naming the window never forces the web view to load: the empty-state
    /// subscription is handed over before `FrontendView` has finished wiring the controller up.
    func updateWindowSceneTitle(isCoveredByEmptyState: Bool) {
        guard role.isMainFrontend, let windowScene = viewIfLoaded?.window?.windowScene else { return }

        applyWindowSceneTitle(windowScene, Self.windowTitle(
            pageTitle: isCoveredByEmptyState ? nil : webView?.title,
            serverName: server.info.name
        ))
    }

    static func windowTitle(pageTitle: String?, serverName: String) -> String {
        let pageTitle = pageTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !pageTitle.isEmpty else { return serverName }

        for suffix in frontendTitleSuffixes where pageTitle.hasSuffix(suffix) {
            let panelTitle = String(pageTitle.dropLast(suffix.count))
            return panelTitle.isEmpty ? pageTitle : panelTitle
        }
        return pageTitle
    }
}
