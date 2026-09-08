import Combine
import Foundation
import Shared

/// Lays the sidebar's pages out as tabs (up to `NativeTabBarConfigurationStore.maximumTabs`, then More and
/// Search) and decides in which tab, if any, the single web frontend is on screen.
@MainActor
final class NativeTabBarViewModel: ObservableObject {
    @Published private(set) var tabItems: [MacSidebarItem] = []
    /// Sidebar pages that did not make it into the bar, in sidebar order.
    @Published private(set) var moreItems: [MacSidebarItem] = []
    /// Settings, Notifications and Profile, minus any pinned to the bar.
    @Published private(set) var fixedItems: [MacSidebarItem] = []
    @Published private(set) var hiddenItems: [MacSidebarItem] = []
    @Published private(set) var selection: NativeTabBarTab
    /// The More tab shows its list until the user opens a page from it, then the frontend takes over.
    @Published private(set) var moreShowsFrontend = false

    let sidebar: MacSidebarViewModel
    /// Opens the frontend's own quick search; the Search tab is an action, never a selected tab.
    var onQuickSearch: (() -> Void)?

    private let configurationStore: NativeTabBarConfigurationStore
    private var configuredItemIds: [String]?
    private var mainItems: [MacSidebarItem] = []
    private var allFixedItems: [MacSidebarItem] = []
    private var currentPath: String?
    private var lastFrontendTab: NativeTabBarTab?
    private var cancellables = Set<AnyCancellable>()

    init(
        sidebar: MacSidebarViewModel,
        overlayState: WebFrontendOverlayState,
        configurationStore: NativeTabBarConfigurationStore? = nil,
        tabBarState: NativeTabBarState? = nil
    ) {
        let configurationStore = configurationStore ?? .shared
        let tabBarState = tabBarState ?? .shared
        self.sidebar = sidebar
        self.configurationStore = configurationStore
        self.configuredItemIds = configurationStore.itemIds(for: sidebar.server.identifier.rawValue)
        self.selection = .more
        self.mainItems = sidebar.mainItems
        self.allFixedItems = sidebar.fixedItems
        self.hiddenItems = sidebar.hiddenItems
        rebuild()
        self.selection = tabItems.first.map { .panel(id: $0.id) } ?? .more
        self.lastFrontendTab = selection

        sidebar.$mainItems
            .combineLatest(sidebar.$fixedItems, sidebar.$hiddenItems)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mainItems, fixedItems, hiddenItems in
                self?.mainItems = mainItems
                self?.allFixedItems = fixedItems
                self?.hiddenItems = hiddenItems
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
        case .search: return false
        }
    }

    /// Every page that can be pinned to the bar. Notifications is a drawer over the current page and Profile
    /// lives in the More header, so only the sidebar pages and Settings qualify.
    var pinnableItems: [MacSidebarItem] {
        mainItems + allFixedItems.filter { item in
            if case .panel = item.kind { return true }
            return false
        }
    }

    /// The More header's rows: the user's profile, the notifications drawer and, for admins, Settings.
    var profileItem: MacSidebarItem? {
        allFixedItems.first { $0.kind == .profile }
    }

    var notificationsItem: MacSidebarItem? {
        allFixedItems.first { $0.kind == .notifications }
    }

    var settingsItem: MacSidebarItem? {
        allFixedItems.first { $0.id == MacSidebarItemsBuilder.settingsPanelPath }
    }

    var canAddTab: Bool {
        tabItems.count < NativeTabBarConfigurationStore.maximumTabs
    }

    func start() {
        sidebar.start()
    }

    func stop() {
        sidebar.stop()
    }

    // MARK: - Selection

    /// The tab bar's own taps. Re-selecting a page tab returns it to its root, re-selecting More closes the
    /// page it was showing, and Search opens Home Assistant's quick search over the frontend.
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
        case .search:
            revealFrontend()
            // The bar has already highlighted Search. Taking the selection there and handing it back on the
            // next turn is what makes SwiftUI move the bar back; an unchanged selection is never re-applied.
            let frontendTab = selection
            selection = .search
            onQuickSearch?()
            DispatchQueue.main.async { [weak self] in
                guard let self, selection == .search else { return }
                selection = frontendTab
            }
        }
    }

    /// A page picked from the More or Search lists.
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
        Current.sceneManager.appCoordinator.done { $0.showSettings(pushOntoNavigationStack: false) }
    }

    // MARK: - Customisation

    func isTab(_ item: MacSidebarItem) -> Bool {
        tabItems.contains(where: { $0.id == item.id })
    }

    func addTab(_ item: MacSidebarItem) {
        guard canAddTab, !isTab(item), pinnableItems.contains(where: { $0.id == item.id }) else { return }
        saveTabs(tabItems.map(\.id) + [item.id])
    }

    func removeTab(_ item: MacSidebarItem) {
        guard isTab(item) else { return }
        saveTabs(tabItems.map(\.id).filter { $0 != item.id })
    }

    func moveTabs(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = tabItems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        saveTabs(ids)
    }

    // MARK: - Visibility

    func canHide(_ item: MacSidebarItem) -> Bool {
        mainItems.contains(where: { $0.id == item.id }) && sidebar.canHide(item)
    }

    func hide(_ item: MacSidebarItem) {
        guard canHide(item) else { return }
        if isTab(item) {
            saveTabs(tabItems.map(\.id).filter { $0 != item.id })
        }
        sidebar.hide(itemId: item.id)
    }

    func show(_ item: MacSidebarItem) {
        sidebar.show(itemId: item.id)
    }

    // MARK: - Private

    private func saveTabs(_ itemIds: [String]) {
        configuredItemIds = itemIds
        configurationStore.setItemIds(itemIds, for: sidebar.server.identifier.rawValue)
        rebuild()
    }

    private func rebuild() {
        let pinnable = pinnableItems
        let tabIds: [String]
        if let configuredItemIds {
            tabIds = configuredItemIds.filter { id in pinnable.contains(where: { $0.id == id }) }
        } else {
            tabIds = mainItems.prefix(NativeTabBarConfigurationStore.maximumTabs).map(\.id)
        }
        let tabItems = tabIds.compactMap { id in pinnable.first(where: { $0.id == id }) }
        let moreItems = mainItems.filter { !tabIds.contains($0.id) }
        let fixedItems = allFixedItems.filter { !tabIds.contains($0.id) }

        if self.tabItems != tabItems {
            self.tabItems = tabItems
        }
        if self.moreItems != moreItems {
            self.moreItems = moreItems
        }
        if self.fixedItems != fixedItems {
            self.fixedItems = fixedItems
        }

        if case let .panel(id) = selection, !tabIds.contains(id) {
            // The selected page left the bar: keep showing it, from More.
            selection = .more
            moreShowsFrontend = true
            lastFrontendTab = .more
        }
        syncSelectionWithCurrentPath()
    }

    /// Follows navigation inside the visible frontend: landing on a pinned page selects its tab. A hidden
    /// frontend is left alone, so a page load finishing behind the More list does not yank the user out.
    private func syncSelectionWithCurrentPath() {
        guard showsFrontend, let itemId = MacSidebarItemsBuilder.itemId(forPath: currentPath),
              tabItems.contains(where: { $0.id == itemId }) else { return }
        let tab = NativeTabBarTab.panel(id: itemId)
        guard selection != tab else { return }
        selection = tab
        lastFrontendTab = tab
    }

    /// Puts the frontend back on screen where it last was, for navigation that happens outside the bar
    /// (deep links, notifications) and for the Search tab's quick search.
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
