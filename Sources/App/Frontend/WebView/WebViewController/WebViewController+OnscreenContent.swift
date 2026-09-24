import AppIntents
import Foundation
import Shared
import UIKit

extension WebViewController {
    /// Publishes what the frontend is showing onto the web view's user activity.
    ///
    /// Called whenever any of its inputs moves — the URL when the frontend navigates, the title when
    /// the document sets one (which for a frontend route change happens a beat after the URL), the
    /// more-info dialog when it opens or closes, and the Siri exposure setting when the user changes
    /// it.
    func updateOnscreenContent() {
        guard let userActivity else { return }

        let serverId = server.identifier.rawValue
        let url = currentPageURL
        forgetOnscreenEntityIfPageChanged(url: url)

        let pageTitle = webView?.title
        let serverName = server.info.name
        let entityId = onscreenEntityId

        // Resolving the entity reads the database, so the publish is a task; the previous one is
        // cancelled because the last thing asked for is the only one that should land.
        onscreenContentTask?.cancel()
        onscreenContentTask = Task { @MainActor [weak self] in
            let identifiers = await Self.publishOnscreenContent(
                onto: userActivity,
                url: url,
                pageTitle: pageTitle,
                serverName: serverName,
                serverId: serverId,
                onscreenEntityId: entityId,
                knownPanelPaths: Self.knownPanelPaths(serverId: serverId)
            )
            guard !Task.isCancelled, let self else { return }
            if #available(iOS 18.4, *) {
                publishOnscreenEntityElements(identifiers)
            }
        }
    }

    /// Reports the entity on screen to the system as an element of the web view, which is the only way
    /// to name it under more than one type at once: an activity carries a single identifier, and a
    /// command binds to the identifier whose type its own parameter takes, so "turn this off" and "add
    /// this to CarPlay" would otherwise be a choice between two.
    ///
    /// The web view is one opaque view, so the element takes its whole area — there is no way to know
    /// where inside it the dialog was drawn, and the dialog covers it anyway.
    @available(iOS 18.4, *)
    func publishOnscreenEntityElements(_ identifiers: [EntityIdentifier]) {
        guard let webView else { return }
        guard !identifiers.isEmpty else {
            webView.appEntityUIElementProvider = nil
            return
        }
        webView.appEntityUIElementProvider = { view, _ in
            Self.onscreenEntityElements(identifiers, bounds: view.bounds)
        }
    }

    /// One element per identifier, all of them the entity the dialog is showing under a different
    /// type, so whichever type a command's parameter takes finds it.
    @available(iOS 18.4, *)
    static func onscreenEntityElements(
        _ identifiers: [EntityIdentifier],
        bounds: CGRect
    ) -> [AppEntityUIElement] {
        identifiers.map { AppEntityUIElement(identifier: $0, bounds: bounds) }
    }

    /// Records the entity the frontend's more-info dialog is showing, so Siri can resolve "this"
    /// against it while it is up.
    ///
    /// The page it opened over is remembered with it: that is what tells us the dialog is gone when
    /// the frontend moves on without saying so. The dialog is drawn over a route rather than being one
    /// — a deep link into it only adds a query item — so the path is what changes when it closes.
    func setOnscreenEntity(entityId: String) {
        // A modal publishes no activity of its own; its host carries what the page inside shows.
        if case .nativeModal = role {
            onNativeModalOnscreenEntity?(entityId)
            return
        }
        guard onscreenEntityId != entityId else { return }
        onscreenEntityId = entityId
        onscreenEntityPath = currentPageURL?.path
        updateOnscreenContent()
    }

    /// Drops the entity the dialog was showing, falling back to the page underneath.
    ///
    /// The id it closed with has to match the one being held: switching straight from one entity to
    /// another is an open followed by nothing, and a close arriving late for the entity before it
    /// must not take the new one down with it.
    func clearOnscreenEntity(entityId: String) {
        if case .nativeModal = role {
            onNativeModalOnscreenEntity?(nil)
            return
        }
        guard onscreenEntityId == entityId else { return }
        onscreenEntityId = nil
        updateOnscreenContent()
    }

    /// A new document means any dialog that was up is gone, and the frontend is in no position to say
    /// so — the page that would have sent the message is the one being replaced. This is the reload
    /// case, pull to refresh included, where the path is the one we were already on.
    func forgetOnscreenEntity() {
        guard onscreenEntityId != nil else { return }
        onscreenEntityId = nil
        onscreenEntityPath = nil
        updateOnscreenContent()
    }

    /// Drops the entity when the frontend has moved to another route while its dialog was up.
    ///
    /// A belt to the frontend's braces: it closes the dialog on navigation and says so, and a missed
    /// message would otherwise leave Siri resolving "this" to something no longer on screen. Assigned
    /// rather than routed through `forgetOnscreenEntity`, which would publish all over again.
    private func forgetOnscreenEntityIfPageChanged(url: URL?) {
        guard onscreenEntityId != nil, url?.path != onscreenEntityPath else { return }
        onscreenEntityId = nil
        onscreenEntityPath = nil
    }

    /// Republishes when the user changes which servers Siri may use, so hiding this one takes what is
    /// on screen off the activity now rather than at the next navigation.
    func observeSiriExposureForOnscreenContent() {
        guard siriExposureObserver == nil else { return }
        siriExposureObserver = NotificationCenter.default.addObserver(
            forName: .siriEntityExposureDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateOnscreenContent()
            }
        }
    }

    /// Writes what is on screen onto the activity: its name, and the identifier the system resolves a
    /// reference to "this" against.
    ///
    /// The name is the one the window already shows — the frontend's own document title with its
    /// " – Home Assistant" suffix taken off, falling back to the server's name while a page has yet to
    /// set one. The identifier is the entity whose details are open, which is the thing being looked
    /// at, and the page underneath it otherwise. A URL on no panel of this server's, with no dialog
    /// open, leaves the activity carrying neither.
    ///
    /// Returns every identifier the entity on screen answers to, for the caller to report as elements
    /// of the web view; the activity itself can only carry the first.
    @discardableResult
    static func publishOnscreenContent(
        onto userActivity: NSUserActivity,
        url: URL?,
        pageTitle: String?,
        serverName: String,
        serverId: String,
        onscreenEntityId: String?,
        knownPanelPaths: Set<String>
    ) async -> [EntityIdentifier] {
        let page = url.flatMap {
            OnscreenPage(
                url: $0,
                title: windowTitle(pageTitle: pageTitle, serverName: serverName),
                serverId: serverId,
                knownPanelPaths: knownPanelPaths
            )
        }

        var entityIdentifiers: [EntityIdentifier] = []
        if #available(iOS 18.2, *), let onscreenEntityId {
            entityIdentifiers = await OnscreenEntityIdentifier.makeAll(
                entityId: onscreenEntityId,
                serverId: serverId
            )
        }

        // Superseded while the entity was being resolved: a newer publish is already on its way with
        // what the screen shows now, so this one has nothing left to say.
        guard !Task.isCancelled else { return [] }

        userActivity.title = page?.title
        if #available(iOS 18.2, *) {
            // The page stands in whenever the dialog names nothing the system could resolve.
            userActivity.appEntityIdentifier = entityIdentifiers.first
                ?? page.flatMap { OnscreenPageIdentifier.make(for: $0) }
        }
        userActivity.becomeCurrent()
        return entityIdentifiers
    }

    /// The panels this server has, as the frontend's own paths. Empty until the panel list has synced,
    /// which simply means nothing is published yet.
    static func knownPanelPaths(serverId: String) -> Set<String> {
        let panels = (try? AppPanel.panels(serverId: serverId)).flatMap { $0 } ?? []
        return Set(panels.map(\.path))
    }
}
