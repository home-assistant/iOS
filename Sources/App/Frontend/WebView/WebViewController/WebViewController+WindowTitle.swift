import Combine
import Shared
import UIKit

// MARK: - Window Title

extension WebViewController {
    private static let frontendTitleSuffixes = [" – Home Assistant", " - Home Assistant"]

    func setupWindowTitleObserver() {
        windowTitleObserver = webView.observe(\.title) { [weak self] _, _ in
            self?.updateWindowSceneTitle()
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

    func updateWindowSceneTitle(isCoveredByEmptyState: Bool) {
        view.window?.windowScene?.title = Self.windowTitle(
            pageTitle: isCoveredByEmptyState ? nil : webView?.title,
            serverName: server.info.name
        )
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
