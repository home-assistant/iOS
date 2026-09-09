import Combine
import Foundation
import Shared

/// Lays the list's first entries out as tabs, then More, and tracks in which tab the single web frontend shows.
@MainActor
final class NativeTabBarViewModel: ObservableObject {
    static let maximumTabs = 4
    static let appSettingsTransitionID = "nativeTabBarAppSettings"

    @Published private(set) var tabItems: [NativeTabBarItem] = []
    /// Entries that did not make it into the bar, in list order.
    @Published private(set) var moreItems: [NativeTabBarItem] = []
    @Published private(set) var fixedItems: [MacSidebarItem] = []
    @Published private(set) var hiddenItems: [NativeTabBarItem] = []
    @Published private(set) var selection: NativeTabBarTab
    /// The More tab shows its list until the user opens a page from it, then the frontend takes over.
    @Published private(set) var moreShowsFrontend = false

    let sidebar: MacSidebarViewModel
    /// Opens the frontend's own quick search; the Search tab is an action, never a selected tab.
    var onQuickSearch: (() -> Void)?
    /// Opens Assist, zooming out of the given window frame when the tap has one.
    var onAssist: ((CGRect?) -> Void)?
    var locateTabButton: (_ title: String, _ trailing: Bool) -> CGRect? = {
        NativeTabBarButtonLocator.frame(ofButtonTitled: $0, trailing: $1)
    }

    private let allServers: () -> [Server]
    private let extrasStore: NativeTabBarExtrasStore
    private var extras: NativeTabBarExtras
    private var mainItems: [MacSidebarItem] = []
    private var hiddenSidebarItems: [MacSidebarItem] = []
    private var currentPath: String?
    private var lastFrontendTab: NativeTabBarTab?
    private var cancellables = Set<AnyCancellable>()

    init(
        sidebar: MacSidebarViewModel,
        overlayState: WebFrontendOverlayState,
        tabBarState: NativeTabBarState? = nil,
        extrasStore: NativeTabBarExtrasStore? = nil,
        servers: @escaping () -> [Server] = { Current.servers.all }
    ) {
        let tabBarState = tabBarState ?? .shared
        let extrasStore = extrasStore ?? .shared
        self.sidebar = sidebar
        self.allServers = servers
        self.extrasStore = extrasStore
        self.extras = extrasStore.extras(for: sidebar.server.identifier.rawValue)
        self.selection = .more
        self.mainItems = sidebar.mainItems
        self.fixedItems = sidebar.fixedItems
        self.hiddenSidebarItems = sidebar.hiddenItems
        rebuild()
        self.selection = tabItems.first?.sidebarItem.map { .panel(id: $0.id) } ?? .more
        self.lastFrontendTab = selection

        sidebar.$mainItems
            .combineLatest(sidebar.$fixedItems, sidebar.$hiddenItems)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mainItems, fixedItems, hiddenItems in
                self?.mainItems = mainItems
                self?.fixedItems = fixedItems
                self?.hiddenSidebarItems = hiddenItems
                self?.rebuild()
            }
            .store(in: &cancellables)

        overlayState.$currentPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                self?.currentPath = path
                self?.syncSelectionWithCurrentPath()
            }
            .store(in: &cancellables)

        overlayState.externalNavigationRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.revealFrontend()
            }
            .store(in: &cancellables)

        tabBarState.moreRequests
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.showMoreList()
            }
            .store(in: &cancellables)
    }

    var showsFrontend: Bool {
        switch selection {
        case .panel: return true
        case .more: return moreShowsFrontend
        case .search, .assist: return false
        }
    }

    /// Search or Assist in the last slot of the bar, shown in the bar's search role rather than as a plain tab.
    var searchRoleItem: NativeTabBarItem? {
        guard tabItems.count == Self.maximumTabs, let last = tabItems.last, last.sidebarItem == nil else { return nil }
        return last
    }

    var regularTabItems: [NativeTabBarItem] {
        tabItems.filter { $0.id != searchRoleItem?.id }
    }

    /// The More header's rows: the user's profile, the notifications drawer and, for admins, Settings.
    var profileItem: MacSidebarItem? {
        fixedItems.first { $0.kind == .profile }
    }

    var notificationsItem: MacSidebarItem? {
        fixedItems.first { $0.kind == .notifications }
    }

    var settingsItem: MacSidebarItem? {
        fixedItems.first { $0.id == MacSidebarItemsBuilder.settingsPanelPath }
    }

    func start() {
        sidebar.start()
    }

    func stop() {
        sidebar.stop()
    }

    // MARK: - Selection

    /// The tab bar's own taps.
    func didSelect(_ tab: NativeTabBarTab) {
        switch tab {
        case let .panel(id):
            selection = tab
            lastFrontendTab = tab
            sidebar.select(itemId: id)
        case .more:
            if selection == .more {
                moreShowsFrontend = false
            } else {
                selection = .more
                moreShowsFrontend = false
            }
        case .search, .assist:
            if tab == .search {
                revealFrontend()
            }
            // Moving the selection there and back on the next turn is what makes SwiftUI un-highlight the tab.
            let previousTab = selection
            selection = tab
            let tapped = tabItems.first { $0.tab == tab }
            perform(tab, sourceFrame: tapped.flatMap { locateTabButton($0.title, $0.id == searchRoleItem?.id) })
            DispatchQueue.main.async { [weak self] in
                guard let self, selection == tab else { return }
                selection = previousTab
            }
        }
    }

    /// An entry picked from the More list; `sourceFrame` is the row's window frame, for Assist to zoom out of.
    func open(_ item: NativeTabBarItem, sourceFrame: CGRect? = nil) {
        if tabItems.contains(where: { $0.id == item.id }) {
            didSelect(item.tab)
            return
        }
        switch item.kind {
        case let .panel(sidebarItem):
            open(sidebarItem)
        case .search:
            revealFrontend()
            perform(item.tab, sourceFrame: sourceFrame)
        case .assist:
            perform(item.tab, sourceFrame: sourceFrame)
        }
    }

    /// A sidebar row: the More header's profile, notifications and Settings, or a page from the More list.
    func open(_ item: MacSidebarItem) {
        if tabItems.contains(where: { $0.id == item.id }) {
            didSelect(.panel(id: item.id))
            return
        }
        switch item.kind {
        case .notifications:
            revealFrontend()
            sidebar.select(itemId: item.id)
        case .panel, .profile:
            selection = .more
            moreShowsFrontend = true
            lastFrontendTab = .more
            sidebar.select(itemId: item.id)
        }
    }

    func showAppSettings() {
        AppSettingsPresenter.shared.presentSettings(zoomingFrom: Self.appSettingsTransitionID)
    }

    // MARK: - Servers

    var servers: [Server] {
        allServers()
    }

    var hasMultipleServers: Bool {
        servers.count > 1
    }

    func open(server: Server) {
        guard server.identifier != sidebar.server.identifier else { return }
        Current.sceneManager.appCoordinator.done { $0.open(server: server) }
    }

    func open(serverIdentifier: Identifier<Server>) {
        guard let server = servers.first(where: { $0.identifier == serverIdentifier }) else { return }
        open(server: server)
    }

    // MARK: - Customisation

    func moveItems(fromOffsets source: IndexSet, toOffset destination: Int) {
        var items = tabItems + moreItems
        items.move(fromOffsets: source, toOffset: destination)
        var extras = extras
        for (index, item) in items.enumerated() where item.sidebarItem == nil {
            extras.setPosition(index, of: item.kind)
        }
        saveExtras(extras)
        sidebar.reorderItems(to: items.compactMap { $0.sidebarItem?.id })
    }

    // MARK: - Visibility

    func canHide(_ item: NativeTabBarItem) -> Bool {
        guard let sidebarItem = item.sidebarItem else { return true }
        return mainItems.contains(where: { $0.id == sidebarItem.id }) && sidebar.canHide(sidebarItem)
    }

    func hide(_ item: NativeTabBarItem) {
        guard canHide(item) else { return }
        if let sidebarItem = item.sidebarItem {
            sidebar.hide(itemId: sidebarItem.id)
        } else {
            var extras = extras
            extras.setPosition(nil, of: item.kind)
            saveExtras(extras)
        }
    }

    func show(_ item: NativeTabBarItem) {
        if let sidebarItem = item.sidebarItem {
            sidebar.show(itemId: sidebarItem.id)
        } else if extras.position(of: item.kind) == nil {
            var extras = extras
            let visible = tabItems + moreItems
            for (index, visibleItem) in visible.enumerated() where visibleItem.sidebarItem == nil {
                extras.setPosition(index, of: visibleItem.kind)
            }
            extras.setPosition(visible.count, of: item.kind)
            saveExtras(extras)
        }
    }

    // MARK: - Private

    private func saveExtras(_ extras: NativeTabBarExtras) {
        self.extras = extras
        extrasStore.setExtras(extras, for: sidebar.server.identifier.rawValue)
        rebuild()
    }

    private func perform(_ tab: NativeTabBarTab, sourceFrame: CGRect?) {
        switch tab {
        case .search: onQuickSearch?()
        case .assist: onAssist?(sourceFrame)
        case .panel, .more: break
        }
    }

    private func rebuild() {
        var items = mainItems.map { NativeTabBarItem(kind: .panel($0)) }
        let extraKinds: [NativeTabBarItem.Kind] = [.search, .assist]
        let positioned = extraKinds
            .compactMap { kind in extras.position(of: kind).map { (kind: kind, position: $0) } }
            .sorted { $0.position < $1.position }
        for extra in positioned {
            items.insert(NativeTabBarItem(kind: extra.kind), at: min(extra.position, items.count))
        }
        let tabItems = Array(items.prefix(Self.maximumTabs))
        let moreItems = Array(items.dropFirst(Self.maximumTabs))
        let hiddenItems = hiddenSidebarItems.map { NativeTabBarItem(kind: .panel($0)) }
            + extraKinds.filter { extras.position(of: $0) == nil }.map { NativeTabBarItem(kind: $0) }

        if self.tabItems != tabItems {
            self.tabItems = tabItems
        }
        if self.moreItems != moreItems {
            self.moreItems = moreItems
        }
        if self.hiddenItems != hiddenItems {
            self.hiddenItems = hiddenItems
        }

        if case let .panel(id) = selection, !tabItems.contains(where: { $0.id == id }) {
            // The selected page left the bar: keep showing it, from More.
            selection = .more
            moreShowsFrontend = true
            lastFrontendTab = .more
        }
        syncSelectionWithCurrentPath()
    }

    /// Follows navigation inside the visible frontend.
    private func syncSelectionWithCurrentPath() {
        guard showsFrontend, let itemId = MacSidebarItemsBuilder.itemId(forPath: currentPath),
              tabItems.contains(where: { $0.id == itemId }) else { return }
        let tab = NativeTabBarTab.panel(id: itemId)
        guard selection != tab else { return }
        selection = tab
        lastFrontendTab = tab
    }

    /// Puts the frontend back on screen where it last was, for navigation that happens outside the bar.
    private func revealFrontend() {
        guard !showsFrontend else { return }
        if case let .panel(id) = lastFrontendTab, tabItems.contains(where: { $0.id == id }) {
            selection = .panel(id: id)
        } else {
            selection = .more
            moreShowsFrontend = true
            lastFrontendTab = .more
        }
        syncSelectionWithCurrentPath()
    }

    private func showMoreList() {
        selection = .more
        moreShowsFrontend = false
    }
}
