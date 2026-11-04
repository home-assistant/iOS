import Foundation

/// The frontend page the web view is showing, as the system needs to understand it.
///
/// The web view is a single opaque view, so nothing inside it is discoverable the way a native view
/// hierarchy's contents are. The two things the web view does tell us — the URL it is on and the
/// title the document set — are enough to name the page, which is what this carries.
struct OnscreenPage: Equatable {
    /// The frontend panel, named the way `PageAppEntity` names it.
    let panelPath: String
    let serverId: String
    /// The page's human-readable name, for anything that shows the activity rather than resolving it.
    let title: String

    /// Fails when the URL's path holds none of the server's panels.
    ///
    /// The panel is matched against the panels this server actually has, rather than assumed to be
    /// the first path component: a server reached under a path prefix puts the prefix there instead
    /// (`https://host/homeassistant/lovelace/0`), and `/` is whichever panel the server made default,
    /// which the URL does not say. Matching also keeps us from naming something that is not a panel,
    /// which the widgets' `PageAppEntity` query could not resolve either.
    init?(url: URL, title: String, serverId: String, knownPanelPaths: Set<String>) {
        guard let panelPath = url.pathComponents.first(where: { knownPanelPaths.contains($0) }) else {
            return nil
        }
        self.panelPath = panelPath
        self.serverId = serverId
        self.title = title
    }
}
