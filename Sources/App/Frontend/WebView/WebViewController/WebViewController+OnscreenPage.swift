import AppIntents
import Foundation
import Shared

extension WebViewController {
    /// Publishes the page on screen onto the web view's user activity.
    ///
    /// Called whenever any of its inputs moves — the URL when the frontend navigates, the title when
    /// the document sets one (which for a frontend route change happens a beat after the URL), and the
    /// Siri exposure setting when the user changes it.
    func updateOnscreenPage() {
        guard let userActivity else { return }

        let serverId = server.identifier.rawValue
        Self.publishOnscreenPage(
            onto: userActivity,
            url: currentPageURL,
            pageTitle: webView?.title,
            serverName: server.info.name,
            serverId: serverId,
            knownPanelPaths: Self.knownPanelPaths(serverId: serverId)
        )
    }

    /// Republishes when the user changes which servers Siri may use, so hiding this one takes the page
    /// off the activity now rather than at the next navigation.
    func observeSiriExposureForOnscreenPage() {
        guard siriExposureObserver == nil else { return }
        siriExposureObserver = NotificationCenter.default.addObserver(
            forName: .siriEntityExposureDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateOnscreenPage()
            }
        }
    }

    /// Writes the page onto the activity: its name, and the identifier the system resolves a reference
    /// to "this page" against.
    ///
    /// The name is the one the window already shows — the frontend's own document title with its
    /// " – Home Assistant" suffix taken off, falling back to the server's name while a page has yet to
    /// set one. A URL on no panel of this server's leaves the activity carrying neither.
    static func publishOnscreenPage(
        onto userActivity: NSUserActivity,
        url: URL?,
        pageTitle: String?,
        serverName: String,
        serverId: String,
        knownPanelPaths: Set<String>
    ) {
        let page = url.flatMap {
            OnscreenPage(
                url: $0,
                title: windowTitle(pageTitle: pageTitle, serverName: serverName),
                serverId: serverId,
                knownPanelPaths: knownPanelPaths
            )
        }

        userActivity.title = page?.title
        if #available(iOS 18.2, *) {
            userActivity.appEntityIdentifier = page.flatMap { OnscreenPageIdentifier.make(for: $0) }
        }
        userActivity.becomeCurrent()
    }

    /// The panels this server has, as the frontend's own paths. Empty until the panel list has synced,
    /// which simply means nothing is published yet.
    static func knownPanelPaths(serverId: String) -> Set<String> {
        let panels = (try? AppPanel.panels(serverId: serverId)).flatMap { $0 } ?? []
        return Set(panels.map(\.path))
    }
}
