import Foundation
import Shared

extension NativeTabBarViewModel {
    /// A tab bar over a fixed set of sidebar pages, for previews and snapshot tests. Nothing is fetched:
    /// the pages come from a cached sidebar snapshot.
    @MainActor
    static func preview(
        hiddenPanelPaths: [String] = [],
        additionalServers: [Server] = [],
        isAdmin: Bool = true,
        suiteName: String = "NativeTabBarPreview"
    ) -> NativeTabBarViewModel {
        let server = ServerFixture.standard
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)

        let snapshotStore = MacSidebarSnapshotStore(userDefaults: userDefaults)
        snapshotStore.store(
            MacSidebarSnapshot(
                panels: previewPanels,
                hiddenPanels: hiddenPanelPaths.isEmpty ? nil : hiddenPanelPaths,
                isAdmin: isAdmin,
                userName: "Bruno"
            ),
            for: server.identifier.rawValue
        )

        let overlayState = WebFrontendOverlayState()
        return NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(
                server: server,
                overlayState: overlayState,
                snapshotStore: snapshotStore
            ),
            overlayState: overlayState,
            tabBarState: NativeTabBarState(),
            servers: { [server] + additionalServers }
        )
    }

    private static var previewPanels: [HAPanel] {
        func panel(_ path: String, component: String = "lovelace", title: String, icon: String? = nil) -> HAPanel {
            HAPanel(
                icon: icon,
                title: title,
                path: path,
                component: component,
                showInSidebar: true,
                defaultVisible: nil,
                rawTitle: title
            )
        }
        return [
            panel("home", component: "home", title: "Overview"),
            panel("garden", title: "Garden", icon: "mdi:flower"),
            panel("energy", component: "energy", title: "Energy"),
            panel("map", component: "map", title: "Map"),
            panel("logbook", component: "logbook", title: "Logbook"),
            panel("history", component: "history", title: "History"),
            panel("media-browser", component: "media-browser", title: "Media"),
            panel("config", component: "config", title: "Settings"),
            panel("profile", component: "profile", title: "Profile"),
        ]
    }
}
