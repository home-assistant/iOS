import Foundation
@testable import HomeAssistant
import Shared
import Testing

@MainActor
struct NativeTabBarViewModelTests {
    private func panel(_ path: String, component: String = "lovelace", title: String) -> HAPanel {
        HAPanel(
            icon: nil,
            title: title,
            path: path,
            component: component,
            showInSidebar: true,
            defaultVisible: nil,
            rawTitle: title
        )
    }

    private var panels: [HAPanel] {
        [
            panel("home", component: "home", title: "Overview"),
            panel("alpha", title: "Alpha"),
            panel("energy", component: "energy", title: "Energy"),
            panel("map", component: "map", title: "Map"),
            panel("config", component: "config", title: "Settings"),
            panel("profile", component: "profile", title: "Profile"),
        ]
    }

    private struct Fixture {
        let sut: NativeTabBarViewModel
        let overlayState: WebFrontendOverlayState
        let tabBarState: NativeTabBarState
        let configurationStore: NativeTabBarConfigurationStore
    }

    private func makeFixture(_ name: String, tabItemIds: [String]? = nil, isAdmin: Bool = true) -> Fixture {
        let suiteName = "NativeTabBarViewModelTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let server = ServerFixture.standard

        let snapshotStore = MacSidebarSnapshotStore(userDefaults: defaults)
        snapshotStore.store(
            MacSidebarSnapshot(panels: panels, isAdmin: isAdmin, userName: "Bruno"),
            for: server.identifier.rawValue
        )
        let configurationStore = NativeTabBarConfigurationStore(userDefaults: defaults)
        if let tabItemIds {
            configurationStore.setItemIds(tabItemIds, for: server.identifier.rawValue)
        }
        let overlayState = WebFrontendOverlayState()
        let tabBarState = NativeTabBarState()
        let sut = NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(server: server, overlayState: overlayState, snapshotStore: snapshotStore),
            overlayState: overlayState,
            configurationStore: configurationStore,
            tabBarState: tabBarState
        )
        return Fixture(
            sut: sut,
            overlayState: overlayState,
            tabBarState: tabBarState,
            configurationStore: configurationStore
        )
    }

    @Test("Without a choice the first sidebar pages fill the bar and the rest go to More")
    func defaultTabs() {
        let fixture = makeFixture("defaults")
        let sut = fixture.sut

        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy"])
        #expect(sut.moreItems.map(\.id) == ["map"])
        #expect(sut.fixedItems.map(\.id) == ["config", "notifications", "profile"])
        #expect(sut.selection == .panel(id: "home"))
        #expect(sut.showsFrontend)
    }

    @Test("A saved choice keeps its order and skips pages that no longer exist")
    func savedTabs() {
        let sut = makeFixture("saved", tabItemIds: ["map", "gone", "config"]).sut

        #expect(sut.tabItems.map(\.id) == ["map", "config"])
        #expect(sut.moreItems.map(\.id) == ["home", "alpha", "energy"])
        #expect(sut.fixedItems.map(\.id) == ["notifications", "profile"])
    }

    @Test("Adding stops at the maximum, removing frees a slot, and both persist")
    func addAndRemove() throws {
        let fixture = makeFixture("addRemove")
        let sut = fixture.sut
        let map = try #require(sut.pinnableItems.first { $0.id == "map" })
        let alpha = try #require(sut.pinnableItems.first { $0.id == "alpha" })
        let notifications = try #require(sut.sidebar.fixedItems.first { $0.id == "notifications" })
        let profile = try #require(sut.sidebar.fixedItems.first { $0.id == "profile" })

        #expect(!sut.canAddTab)
        sut.addTab(map)
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy"])

        sut.removeTab(alpha)
        #expect(sut.canAddTab)
        sut.addTab(map)
        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map"])
        #expect(fixture.configurationStore.itemIds(for: sut.sidebar.server.identifier.rawValue) == [
            "home",
            "energy",
            "map",
        ])

        sut.removeTab(map)
        sut.addTab(notifications)
        sut.addTab(profile)
        #expect(sut.tabItems.map(\.id) == ["home", "energy"])
        #expect(sut.pinnableItems.map(\.id) == ["home", "alpha", "energy", "map", "config"])
    }

    @Test("The More header exposes profile, notifications and, for admins only, Settings")
    func headerItems() {
        let admin = makeFixture("headerAdmin").sut
        #expect(admin.profileItem?.kind == .profile)
        #expect(admin.notificationsItem?.kind == .notifications)
        #expect(admin.settingsItem?.id == "config")

        let user = makeFixture("headerUser", isAdmin: false).sut
        #expect(user.settingsItem == nil)
        #expect(user.profileItem != nil)
    }

    @Test("Reordering persists the new order")
    func reorder() {
        let fixture = makeFixture("reorder")
        fixture.sut.moveTabs(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        #expect(fixture.sut.tabItems.map(\.id) == ["energy", "home", "alpha"])
        #expect(fixture.configurationStore.itemIds(for: ServerFixture.standard.identifier.rawValue) == [
            "energy",
            "home",
            "alpha",
        ])
    }

    @Test("Navigating the visible frontend to a pinned page selects its tab; hidden, it is left alone")
    func selectionFollowsPath() async throws {
        let fixture = makeFixture("path")
        let sut = fixture.sut

        fixture.overlayState.currentPath = "/energy/overview"
        await Task.yield()
        #expect(sut.selection == .panel(id: "energy"))

        sut.didSelect(.more)
        #expect(!sut.showsFrontend)
        fixture.overlayState.currentPath = "/alpha"
        await Task.yield()
        #expect(sut.selection == .more)
    }

    @Test("Opening a page that is not pinned shows the frontend from More; the hamburger brings the list back")
    func openFromMore() async throws {
        let fixture = makeFixture("openFromMore")
        let sut = fixture.sut
        let map = try #require(sut.moreItems.first)

        sut.didSelect(.more)
        sut.open(map)
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)
        #expect(sut.showsFrontend)

        fixture.tabBarState.requestMore()
        await Task.yield()
        #expect(sut.selection == .more)
        #expect(!sut.moreShowsFrontend)

        sut.open(map)
        sut.didSelect(.more)
        #expect(!sut.moreShowsFrontend)
    }

    @Test("Navigation from outside the bar brings the frontend back where it last was")
    func externalNavigationRevealsFrontend() async throws {
        let fixture = makeFixture("external")
        let sut = fixture.sut

        sut.didSelect(.panel(id: "alpha"))
        sut.didSelect(.more)
        #expect(!sut.showsFrontend)

        fixture.overlayState.externalNavigationRequests.send()
        await Task.yield()
        #expect(sut.selection == .panel(id: "alpha"))
    }

    @Test("Removing the selected tab keeps its page on screen from More")
    func removingSelectedTab() throws {
        let sut = makeFixture("removeSelected").sut
        let alpha = try #require(sut.tabItems.first { $0.id == "alpha" })

        sut.didSelect(.panel(id: "alpha"))
        sut.removeTab(alpha)

        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)
    }

    @Test("The Search tab opens the frontend's quick search and hands the selection back to the frontend")
    func searchTabOpensQuickSearch() async throws {
        let sut = makeFixture("search").sut
        var quickSearchCount = 0
        sut.onQuickSearch = { quickSearchCount += 1 }

        sut.didSelect(.more)
        sut.didSelect(.search)
        #expect(quickSearchCount == 1)
        #expect(sut.selection == .search)

        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.selection == .panel(id: "home"))
        #expect(sut.showsFrontend)
    }

    @Test("Notifications reveal the frontend and open the drawer; header pages open from More")
    func headerItemsOpen() throws {
        let sut = makeFixture("headerOpen").sut
        var navigated: [String] = []
        var notificationsShown = 0
        sut.sidebar.onNavigate = { navigated.append($0) }
        sut.sidebar.onShowNotifications = { notificationsShown += 1 }
        let notifications = try #require(sut.notificationsItem)
        let profile = try #require(sut.profileItem)

        sut.didSelect(.more)
        sut.open(notifications)
        #expect(notificationsShown == 1)
        #expect(sut.selection == .panel(id: "home"))

        sut.open(profile)
        #expect(navigated == ["/profile"])
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)

        sut.didSelect(.panel(id: "alpha"))
        #expect(navigated == ["/profile", "/alpha"])
        sut.didSelect(.panel(id: "alpha"))
        #expect(navigated == ["/profile", "/alpha", "/alpha"])
    }

    @Test("App Settings goes through the app coordinator")
    func showAppSettings() async {
        let sut = makeFixture("appSettings").sut
        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)

        await withCheckedContinuation { continuation in
            coordinator.onShowSettings = { continuation.resume() }
            sut.showAppSettings()
        }
        #expect(coordinator.showSettingsCalled)
        #expect(!coordinator.showSettingsPushedOntoNavigationStack)
    }

    @Test("Starting and stopping forwards to the sidebar without a connection")
    func startStop() {
        let sut = makeFixture("startStop").sut
        sut.start()
        sut.stop()
        #expect(sut.tabItems.count == 3)
    }

    @Test("Unreadable stored tab choices are dropped instead of failing every launch")
    func configurationStoreDropsCorruptData() {
        let suiteName = "NativeTabBarViewModelTests.corrupt"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Data("not json".utf8), forKey: NativeTabBarConfigurationStore.storageKey)

        let store = NativeTabBarConfigurationStore(userDefaults: defaults)
        #expect(store.itemIds(for: "server") == nil)
        #expect(defaults.data(forKey: NativeTabBarConfigurationStore.storageKey) == nil)

        store.setItemIds(["a"], for: "server")
        store.setItemIds(["a"], for: "server")
        #expect(NativeTabBarConfigurationStore(userDefaults: defaults).itemIds(for: "server") == ["a"])
    }

    @Test("The configuration store caps and persists per server")
    func configurationStore() {
        let suiteName = "NativeTabBarViewModelTests.store"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let store = NativeTabBarConfigurationStore(userDefaults: defaults)
        store.setItemIds(["a", "b", "c", "d"], for: "server")
        #expect(store.itemIds(for: "server") == ["a", "b", "c"])
        #expect(store.itemIds(for: "other") == nil)

        let reloaded = NativeTabBarConfigurationStore(userDefaults: defaults)
        #expect(reloaded.itemIds(for: "server") == ["a", "b", "c"])
    }
}
