import Shared
import SwiftUI

/// Puts the native home over the web frontend while the frontend is on the built-in Overview.
///
/// A modifier rather than a branch in ``HomeAssistantView``: that view already chooses between two
/// layouts and a standby overlay, and the native home has to sit over all of them the same way.
struct NativeHomeOverlay: ViewModifier {
    @ObservedObject private var state = NativeHomeState.shared

    private let server: Server
    /// The frontend's current path, as the web view reports it.
    private let currentPath: String?

    init(server: Server, currentPath: String?) {
        self.server = server
        self.currentPath = currentPath
    }

    func body(content: Content) -> some View {
        content.overlay {
            if state.covers(path: currentPath, homePanelPath: homePanelPath) {
                NativeHomeView(server: server)
                    .transition(.opacity)
            }
        }
    }

    /// The path the server registers its built-in dashboard under — `home` on every server that has
    /// one. Read from the panels the app already stores rather than assumed, because a server
    /// without the built-in dashboard has no native home to show.
    private var homePanelPath: String? {
        guard let panels = try? AppPanel.panels(serverId: server.identifier.rawValue) else {
            return nil
        }
        return AppPanel.homeDashboardPath(in: panels)
    }
}

extension View {
    /// Covers the frontend with the native home while it is showing the built-in Overview.
    func nativeHomeOverlay(server: Server, currentPath: String?) -> some View {
        modifier(NativeHomeOverlay(server: server, currentPath: currentPath))
    }
}
