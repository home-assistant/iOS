import AppIntents
import Foundation
import Shared

extension WebViewController {
    /// Publishes the page on screen onto the web view's user activity: its name, and the identifier the
    /// system resolves a reference to "this page" against.
    ///
    /// Called whenever either of its two inputs moves — the URL when the frontend navigates, the title
    /// when the document sets one, which for a frontend route change happens a beat after the URL.
    func updateOnscreenPage() {
        guard let userActivity else { return }

        let page = currentOnscreenPage()
        userActivity.title = page?.title
        if #available(iOS 18.0, *) {
            userActivity.appEntityIdentifier = page.flatMap { OnscreenPageIdentifier.make(for: $0) }
        }
        userActivity.becomeCurrent()
    }

    /// The title is the one the window already shows: the frontend's own document title with its
    /// " – Home Assistant" suffix taken off, falling back to the server's name while a page has yet to
    /// set one.
    private func currentOnscreenPage() -> OnscreenPage? {
        guard let currentPageURL else { return nil }
        return OnscreenPage(
            url: currentPageURL,
            title: Self.windowTitle(pageTitle: webView?.title, serverName: server.info.name),
            serverId: server.identifier.rawValue
        )
    }
}
