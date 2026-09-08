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
    }

    private func makeFixture(
        _ name: String,
        panelOrder: [String]? = nil,
        hiddenPanels: [String]? = nil,
        isAdmin: Bool = true
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
        let sut = NativeTabBarViewModel(
            sidebar: MacSidebarViewModel(server: server, overlayState: overlayState, snapshotStore: snapshotStore),
            overlayState: overlayState,
            tabBarState: tabBarState
        )
        return Fixture(
            sut: sut,
            overlayState: overlayState,
            tabBarState: tabBarState,
            snapshotStore: snapshotStore
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

    @Test("The sidebar order decides which pages are tabs")
    func sidebarOrderDecidesTabs() {
        let sut = makeFixture("order", panelOrder: ["map", "energy", "home", "alpha"]).sut

        #expect(sut.tabItems.map(\.id) == ["map", "energy", "home"])
        #expect(sut.moreItems.map(\.id) == ["alpha"])
        #expect(sut.selection == .panel(id: "map"))
    }

    @Test("Reordering pages moves them in and out of the bar and is saved with the sidebar preferences")
    func reorder() async throws {
        let fixture = makeFixture("reorder")
        let sut = fixture.sut

        sut.moveItems(fromOffsets: IndexSet(integer: 3), toOffset: 0)
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["map", "home", "alpha"])
        #expect(sut.moreItems.map(\.id) == ["energy"])
        #expect(fixture.snapshotStore.snapshot(for: ServerFixture.standard.identifier.rawValue)?.panelOrder == [
            "map",
            "home",
            "alpha",
            "energy",
        ])
    }

    @Test("Moving the selected tab out of the bar keeps its page on screen from More")
    func reorderingSelectedTabOut() async throws {
        let sut = makeFixture("reorderSelected").sut

        sut.didSelect(.panel(id: "alpha"))
        sut.moveItems(fromOffsets: IndexSet(integer: 1), toOffset: 4)
        await Task.yield()

        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map"])
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)
    }

    @Test("Pages hidden in the sidebar preferences stay out of the bar and More but are listed as hidden")
    func hiddenPagesStayOut() {
        let sut = makeFixture("hidden", hiddenPanels: ["alpha"]).sut

        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map"])
        #expect(sut.moreItems.isEmpty)
        #expect(sut.hiddenItems.map(\.id) == ["alpha"])
    }

    @Test("Only sidebar pages other than the default dashboard can be hidden")
    func canHide() throws {
        let sut = makeFixture("canHide").sut
        let home = try #require(sut.tabItems.first { $0.id == "home" })
        let map = try #require(sut.moreItems.first { $0.id == "map" })
        let settings = try #require(sut.settingsItem)
        let profile = try #require(sut.profileItem)

        #expect(!sut.canHide(home))
        #expect(sut.canHide(map))
        #expect(!sut.canHide(settings))
        #expect(!sut.canHide(profile))
    }

    @Test("Hiding a page removes it from More; showing it again appends it to More")
    func hideAndShowFromMore() async throws {
        let fixture = makeFixture("hideShow")
        let sut = fixture.sut
        let map = try #require(sut.moreItems.first { $0.id == "map" })

        sut.hide(map)
        await Task.yield()
        #expect(sut.moreItems.isEmpty)
        #expect(sut.hiddenItems.map(\.id) == ["map"])
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy"])

        let hiddenMap = try #require(sut.hiddenItems.first)
        sut.show(hiddenMap)
        await Task.yield()
        #expect(sut.moreItems.map(\.id) == ["map"])
        #expect(sut.hiddenItems.isEmpty)
    }

    @Test("Hiding the selected tab promotes the next page and keeps the hidden page on screen from More")
    func hideTab() async throws {
        let fixture = makeFixture("hideTab")
        let sut = fixture.sut
        let alpha = try #require(sut.tabItems.first { $0.id == "alpha" })

        sut.didSelect(.panel(id: "alpha"))
        sut.hide(alpha)
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map"])
        #expect(sut.hiddenItems.map(\.id) == ["alpha"])
        #expect(sut.selection == .more)
        #expect(sut.moreShowsFrontend)

        let hiddenAlpha = try #require(sut.hiddenItems.first)
        sut.show(hiddenAlpha)
        await Task.yield()
        #expect(sut.tabItems.map(\.id) == ["home", "energy", "map"])
        #expect(sut.moreItems.map(\.id) == ["alpha"])
    }

    @Test("The default dashboard and header pages ignore hide requests")
    func hideIgnoresProtectedPages() async throws {
        let sut = makeFixture("hideProtected").sut
        let home = try #require(sut.tabItems.first { $0.id == "home" })
        let settings = try #require(sut.settingsItem)

        sut.hide(home)
        sut.hide(settings)
        await Task.yield()
        #expect(sut.hiddenItems.isEmpty)
        #expect(sut.tabItems.map(\.id) == ["home", "alpha", "energy"])
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
}
