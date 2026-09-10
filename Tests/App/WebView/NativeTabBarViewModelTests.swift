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
        let snapshotStore: MacSidebarSnapshotStore
        let extrasStore: NativeTabBarExtrasStore
    }

    private let search = NativeTabBarItem.searchID
    private let assist = NativeTabBarItem.assistID

    private func makeFixture(
        _ name: String,
        panelOrder: [String]? = nil,
        hiddenPanels: [String]? = nil,
        isAdmin: Bool = true,
        additionalServers: [Server] = []
    ) -> Fixture {
        let suiteName = "NativeTabBarViewModelTests.\(name)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let server = ServerFixture.standard

        let snapshotStore = MacSidebarSnapshotStore(userDefaults: defaults)
        snapshotStore.store(
            MacSidebarSnapshot(
                panels: panels,
                panelOrder: panelOrder,
                hiddenPanels: hiddenPanels,
                isAdmin: isAdmin,
                userName: "Bruno"
            ),
            for: server.identifier.rawValue
        )
        let overlayState = WebFrontendOverlayState()
        let tabBarState = NativeTabBarState()
        let extrasStore = NativeTabBarExtrasStore(userDefaults: defaults)
        let sut = NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(server: server, overlayState: overlayState, snapshotStore: snapshotStore),
            overlayState: overlayState,
            tabBarState: tabBarState,
            extrasStore: extrasStore,
            servers: { [server] + additionalServers }
        )
        return Fixture(
            sut: sut,
            overlayState: overlayState,
            tabBarState: tabBarState,
            snapshotStore: snapshotStore,
            extrasStore: extrasStore
        )
    }

    private func item(_ id: String, in sut: NativeTabBarViewModel) throws -> NativeTabBarItem {
        try #require((sut.tabItems + sut.moreItems + sut.hiddenItems).first { $0.id == id })
    }

    @Test("Without a choice the first sidebar pages fill the bar and the rest go to More")
    func defaultTabs() {
        let fixture = makeFixture("defaults")
        let sut = fixture.sut

        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy", search])
        #expect(sut.regularTabItems.map(\.id) == ["home", "alpha", "energy"])
        #expect(sut.searchRoleItem?.kind == .search)
        #expect(sut.moreItems.map(\.id) == ["map", assist])
        #expect(sut.fixedItems.map(\.id) == ["config", "notifications", "profile"])
        #expect(sut.selection == .panel(id: "home"))
        #expect(sut.showsFrontend)
    }

    @Test("The sidebar order decides which pages are tabs")
    func sidebarOrderDecidesTabs() {
        let sut = makeFixture("order", panelOrder: ["map", "energy", "home", "alpha"]).sut

        #expect(sut.tabItems.map(\.id) == ["map", "energy", "home", search])
        #expect(sut.moreItems.map(\.id) == ["alpha", assist])
        #expect(sut.selection == .panel(id: "map"))
    }

    @Test("Reordering moves entries in and out of the bar; a dashboard in the fourth slot makes four plain tabs")
    func reorder() async throws {
        let fixture = makeFixture("reorder")
        let sut = fixture.sut

        sut.moveItems(fromOffsets: IndexSet(integer: 4), toOffset: 0)
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["map", "home", "alpha", "energy"])
        #expect(sut.searchRoleItem == nil)
        #expect(sut.regularTabItems.count == 4)
        #expect(sut.moreItems.map(\.id) == [search, assist])
        #expect(fixture.snapshotStore.snapshot(for: ServerFixture.standard.identifier.rawValue)?.panelOrder == [
            "map",
            "home",
            "alpha",
            "energy",
        ])
        let extras = fixture.extrasStore.extras(for: ServerFixture.standard.identifier.rawValue)
        #expect(extras.searchPosition == 4)
        #expect(extras.assistPosition == 5)
    }

    @Test("Assist in the fourth slot takes the search role and Search moves on to More")
    func assistTakesTheSearchRole() throws {
        let fixture = makeFixture("assistRole")
        let sut = fixture.sut

        sut.moveItems(fromOffsets: IndexSet(integer: 5), toOffset: 3)
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy", assist])
        #expect(sut.searchRoleItem?.kind == .assist)
        #expect(sut.regularTabItems.map(\.id) == ["home", "alpha", "energy"])
        #expect(sut.moreItems.map(\.id) == [search, "map"])
        let persisted = NativeTabBarExtrasStore(
            userDefaults: UserDefaults(suiteName: "NativeTabBarViewModelTests.assistRole")!
        )
        #expect(persisted.extras(for: ServerFixture.standard.identifier.rawValue).assistPosition == 3)
        #expect(persisted.extras(for: ServerFixture.standard.identifier.rawValue).searchPosition == 4)
    }

    @Test("Search in an earlier slot is a plain tab and the fourth dashboard fills the bar")
    func searchAsPlainTab() {
        let sut = makeFixture("searchPlain").sut

        sut.moveItems(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        #expect(sut.tabItems.map(\.id) == [search, "home", "alpha", "energy"])
        #expect(sut.searchRoleItem == nil)
        #expect(sut.regularTabItems.map(\.id) == [search, "home", "alpha", "energy"])
    }

    @Test("Hidden Search and Assist wait in the hidden list and come back at the end")
    func hideAndShowExtras() throws {
        let sut = makeFixture("hideExtras").sut

        try sut.hide(item(search, in: sut))
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy", "map"])
        #expect(sut.moreItems.map(\.id) == [assist])
        #expect(sut.hiddenItems.map(\.id) == [search])

        try sut.show(item(search, in: sut))
        #expect(sut.moreItems.map(\.id) == [assist, search])
        #expect(sut.hiddenItems.isEmpty)

        try sut.show(item(search, in: sut))
        #expect(sut.moreItems.map(\.id) == [assist, search])
    }

    @Test("Assist as a tab runs the action and hands the selection back; from More it leaves the selection alone")
    func assistActions() async throws {
        let sut = makeFixture("assistActions").sut
        var sourceFrames: [CGRect?] = []
        sut.onAssist = { sourceFrames.append($0) }
        sut.locateTabButton = { title, trailing in
            title == L10n.TabBar.Item.assist && trailing ? CGRect(x: 1, y: 2, width: 3, height: 4) : nil
        }

        sut.didSelect(.more)
        try sut.open(item(assist, in: sut), sourceFrame: CGRect(x: 5, y: 6, width: 7, height: 8))
        #expect(sourceFrames == [CGRect(x: 5, y: 6, width: 7, height: 8)])
        #expect(sut.selection == .more)
        #expect(!sut.moreShowsFrontend)

        sut.moveItems(fromOffsets: IndexSet(integer: 5), toOffset: 3)
        sut.didSelect(.assist)
        #expect(sourceFrames.count == 2)
        #expect(sourceFrames.last == CGRect(x: 1, y: 2, width: 3, height: 4))
        #expect(sut.selection == .assist)
        #expect(!sut.showsFrontend)

        try await Task.sleep(for: .milliseconds(50))
        #expect(sut.selection == .more)
        #expect(!sut.moreShowsFrontend)
    }

    @Test("The extras store keeps positions per server and drops unreadable data")
    func extrasStore() {
        let suiteName = "NativeTabBarViewModelTests.extrasStore"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(Data("not json".utf8), forKey: NativeTabBarExtrasStore.storageKey)

        let store = NativeTabBarExtrasStore(userDefaults: defaults)
        #expect(store.extras(for: "server") == .standard)
        #expect(defaults.data(forKey: NativeTabBarExtrasStore.storageKey) == nil)

        let extras = NativeTabBarExtras(searchPosition: nil, assistPosition: 1)
        store.setExtras(extras, for: "server")
        store.setExtras(extras, for: "server")
        #expect(NativeTabBarExtrasStore(userDefaults: defaults).extras(for: "server") == extras)
        #expect(NativeTabBarExtrasStore(userDefaults: defaults).extras(for: "other") == .standard)
    }

    @Test("Moving the selected tab out of the bar keeps its page on screen from More")
    func reorderingSelectedTabOut() async throws {
        let sut = makeFixture("reorderSelected").sut

        sut.didSelect(.panel(id: "alpha"))
        sut.moveItems(fromOffsets: IndexSet(integer: 1), toOffset: 6)
        await Task.yield()

        #expect(sut.tabItems.map(\.id) == ["home", "energy", search, "map"])
        #expect(sut.searchRoleItem == nil)
        #expect(sut.moreItems.map(\.id) == [assist, "alpha"])
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)
    }

    @Test("Pages hidden in the sidebar preferences stay out of the bar and More but are listed as hidden")
    func hiddenPagesStayOut() {
        let sut = makeFixture("hidden", hiddenPanels: ["alpha"]).sut

        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map", search])
        #expect(sut.moreItems.map(\.id) == [assist])
        #expect(sut.hiddenItems.map(\.id) == ["alpha"])
    }

    @Test("Everything but the default dashboard and the header rows can be hidden")
    func canHide() throws {
        let sut = makeFixture("canHide").sut
        let settings = try #require(sut.settingsItem)
        let home = try item("home", in: sut)
        let map = try item("map", in: sut)
        let searchItem = try item(search, in: sut)
        let assistItem = try item(assist, in: sut)

        #expect(!sut.canHide(home))
        #expect(sut.canHide(map))
        #expect(sut.canHide(searchItem))
        #expect(sut.canHide(assistItem))
        #expect(!sut.canHide(NativeTabBarItem(kind: .panel(settings))))
    }

    @Test("Hiding a page removes it from More; showing it again appends it to More")
    func hideAndShowFromMore() async throws {
        let sut = makeFixture("hideShow").sut

        try sut.hide(item("map", in: sut))
        await Task.yield()
        #expect(sut.moreItems.map(\.id) == [assist])
        #expect(sut.hiddenItems.map(\.id) == ["map"])
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy", search])

        try sut.show(item("map", in: sut))
        await Task.yield()
        #expect(sut.moreItems.map(\.id) == ["map", assist])
        #expect(sut.hiddenItems.isEmpty)
    }

    @Test("Hiding the selected tab promotes the next page and keeps the hidden page on screen from More")
    func hideTab() async throws {
        let sut = makeFixture("hideTab").sut

        sut.didSelect(.panel(id: "alpha"))
        try sut.hide(item("alpha", in: sut))
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map", search])
        #expect(sut.hiddenItems.map(\.id) == ["alpha"])
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)

        try sut.show(item("alpha", in: sut))
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map", search])
        #expect(sut.moreItems.map(\.id) == ["alpha", assist])
    }

    @Test("The default dashboard and header pages ignore hide requests")
    func hideIgnoresProtectedPages() async throws {
        let sut = makeFixture("hideProtected").sut
        let settings = try #require(sut.settingsItem)

        try sut.hide(item("home", in: sut))
        sut.hide(NativeTabBarItem(kind: .panel(settings)))
        await Task.yield()
        #expect(sut.hiddenItems.isEmpty)
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy", search])
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

    @Test("App Settings opens the settings sheet zooming out of the More tab's gear")
    func showAppSettings() {
        let sut = makeFixture("appSettings").sut
        let presenter = AppSettingsPresenter.shared
        defer {
            presenter.isSheetPresented = false
            presenter.sheetDismissed()
        }

        sut.showAppSettings()
        #expect(presenter.isSheetPresented)
        #expect(presenter.mode == .full)
        #expect(presenter.zoomSourceID == NativeTabBarViewModel.appSettingsTransitionID)
    }

    @Test("Switching to another server goes through the app coordinator; the current one is left alone")
    func openServer() async {
        let other = ServerFixture.withRemoteConnection
        let single = makeFixture("singleServer").sut
        #expect(!single.hasMultipleServers)

        let sut = makeFixture("openServer", additionalServers: [other]).sut
        #expect(sut.hasMultipleServers)
        #expect(sut.servers.map(\.identifier) == [ServerFixture.standard.identifier, other.identifier])

        let coordinator = MockAppCoordinator()
        Current.sceneManager.registerAppCoordinator(coordinator)
        sut.open(server: ServerFixture.standard)
        await withCheckedContinuation { continuation in
            coordinator.onOpenServer = { continuation.resume() }
            sut.open(server: other)
        }
        #expect(coordinator.openedServers.map(\.identifier) == [other.identifier])

        sut.open(serverIdentifier: "unknown")
        await withCheckedContinuation { continuation in
            coordinator.onOpenServer = { continuation.resume() }
            sut.open(serverIdentifier: other.identifier)
        }
        #expect(coordinator.openedServers.map(\.identifier) == [other.identifier, other.identifier])
    }

    @Test("Customize opens from the More button with a zoom and from a long press without one")
    func showCustomize() {
        let sut = makeFixture("customize").sut
        #expect(!sut.showsCustomize)

        sut.showCustomize(zoomingFromButton: false)
        #expect(sut.showsCustomize)
        #expect(!sut.customizeZoomsFromButton)

        sut.showsCustomize = false
        sut.showCustomize(zoomingFromButton: true)
        #expect(sut.showsCustomize)
        #expect(sut.customizeZoomsFromButton)
    }

    @Test("Without an injected list the servers are the app's registered servers")
    func defaultServers() {
        let overlayState = WebFrontendOverlayState()
        let sut = NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(server: ServerFixture.standard, overlayState: overlayState),
            overlayState: overlayState,
            tabBarState: NativeTabBarState()
        )
        #expect(sut.servers.map(\.identifier) == Current.servers.all.map(\.identifier))
    }

    @Test("Starting and stopping forwards to the sidebar without a connection")
    func startStop() {
        let sut = makeFixture("startStop").sut
        sut.start()
        sut.stop()
        #expect(sut.tabItems.count == 4)
    }
}
