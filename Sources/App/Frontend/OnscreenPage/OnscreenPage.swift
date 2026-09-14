import Foundation

/// The frontend page the web view is showing, as the system needs to understand it.
///
/// The web view is a single opaque view, so nothing inside it is discoverable the way a native view
/// hierarchy's contents are. The two things the web view does tell us — the URL it is on and the
/// title the document set — are enough to name the page, which is what this carries.
struct OnscreenPage: Equatable {
    /// The frontend panel, which is the first component of the URL's path.
    let panelPath: String
    let serverId: String
    /// The page's human-readable name, for anything that shows the activity rather than resolving it.
    let title: String

    /// Fails when the URL names no panel we could resolve.
    ///
    /// Panels are the first path component — `/lovelace/0` is the second view of the `lovelace`
    /// panel — and `/` is whichever panel the server made default, which the URL alone does not say.
    /// Rather than guess at that, a URL with no path yields no page.
    init?(url: URL, title: String, serverId: String) {
        guard let panelPath = url.pathComponents.first(where: { $0 != "/" && !$0.isEmpty }) else {
            return nil
        }
        self.panelPath = panelPath
        self.serverId = serverId
        self.title = title
    }
}
