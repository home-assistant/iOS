import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct MacSidebarCachingTests {
    private func panel(
        _ path: String,
        component: String = "lovelace",
        title: String? = nil
    ) -> HAPanel {
        HAPanel(
            icon: nil,
            title: title ?? path,
            path: path,
            component: component,
            showInSidebar: true,
            defaultVisible: nil,
            rawTitle: title
        )
    }

    private var cachedPanels: [HAPanel] {
        [
            panel("home", component: "home", title: "Overview"),
            panel("alpha", title: "Alpha"),
            panel("zeta", title: "Zeta"),
            panel("config", component: "config", title: "Settings"),
        ]
    }

    private func makeUserDefaults(_ name: String) -> UserDefaults {
        let suiteName = "MacSidebarCachingTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeSnapshotStore(_ name: String) -> MacSidebarSnapshotStore {
        MacSidebarSnapshotStore(userDefaults: makeUserDefaults(name))
    }

    @Test("A new window renders the cached arrangement instead of rebuilding it from nothing")
    func startsFromTheCachedArrangement() {
        let server = ServerFixture.standard
        let store = makeSnapshotStore("cachedArrangement")
        store.store(
            MacSidebarSnapshot(
                panels: cachedPanels,
                panelOrder: ["home", "zeta"],
                hiddenPanels: ["alpha"],
                isAdmin: true,
                userName: "Bruno"
            ),
            for: server.identifier.rawValue
        )

        let sut = MacSidebarViewModel(
            server: server,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: store
        )

        #expect(sut.mainItems.map(\.id) == ["home", "zeta"])
        #expect(sut.hiddenItems.map(\.id) == ["alpha"])
        #expect(sut.fixedItems.map(\.id) == ["config", "notifications", "profile"])
        #expect(sut.fixedItems.last?.title == "Bruno")
    }

    @Test("A cached non-admin keeps the settings row out instead of having it appear later")
    func startsWithoutTheSettingsRowForANonAdmin() {
        let server = ServerFixture.standard
        let store = makeSnapshotStore("nonAdmin")
        store.store(MacSidebarSnapshot(panels: cachedPanels), for: server.identifier.rawValue)

        let sut = MacSidebarViewModel(
            server: server,
            overlayState: WebFrontendOverlayState(),
            snapshotStore: store
        )

        #expect(sut.fixedItems.map(\.id) == ["notifications", "profile"])
    }

    @Test("Cached arrangements outlive the window that resolved them")
    func persistsAcrossStoreInstances() {
        let defaults = makeUserDefaults("persistence")
        let snapshot = MacSidebarSnapshot(
            panels: cachedPanels,
            panelOrder: ["home", "zeta"],
            hiddenPanels: ["alpha"],
            legacyDefaultPanel: "zeta",
            isAdmin: true,
            userName: "Bruno"
        )

        MacSidebarSnapshotStore(userDefaults: defaults).store(snapshot, for: "server-1")

        let restored = MacSidebarSnapshotStore(userDefaults: defaults)
        #expect(restored.snapshot(for: "server-1") == snapshot)
        #expect(restored.snapshot(for: "server-2") == nil)
    }
}
