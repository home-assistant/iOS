import Combine
import Foundation
import HAKit
import Shared

@MainActor
final class MacSidebarViewModel: ObservableObject {
    @Published private(set) var mainItems: [MacSidebarItem] = []
    @Published private(set) var fixedItems: [MacSidebarItem] = []
    /// Panels the user can add back while editing; see `MacSidebarItemsBuilder.hiddenItems`.
    @Published private(set) var hiddenItems: [MacSidebarItem] = []
    @Published var isEditing = false
    @Published private(set) var selectedItemId: String?
    @Published private(set) var user: HAResponseCurrentUser?

    /// Legacy per-browser sidebar preferences the frontend still honours when the server-side user data
    /// has none; see the `localStorage` fallbacks in `ha-sidebar.ts` and `data/panel.ts`.
    enum LegacyStorageKey: String, CaseIterable {
        case panelOrder = "sidebarPanelOrder"
        case hiddenPanels = "sidebarHiddenPanels"
        case defaultPanel
    }

    let server: Server
    var onNavigate: ((String) -> Void)?
    var onShowNotifications: (() -> Void)?
    /// Reads a `localStorage` value from the running frontend; the result is the raw JSON string or nil.
    var readLocalStorage: ((_ key: String, _ completion: @escaping (String?) -> Void) -> Void)?

    private var panels: [HAPanel] = []
    private var defaultPanelPath = MacSidebarItemsBuilder.fallbackDefaultPanelPath
    private var sidebarUserData = FrontendSidebarUserData()
    private var legacyPanelOrder: [String]?
    private var legacyHiddenPanels: [String]?
    private var legacyDefaultPanel: String?
    private var coreUserData = FrontendDefaultPanelData()
    private var userDefaultPanel: String? { coreUserData.defaultPanel }
    private var systemDefaultPanel: String?
    private var notificationIds: Set<String> = []
    private var currentPath: String?
    private var tokens: [HACancellable] = []
    private var cancellables = Set<AnyCancellable>()

    init(server: Server, overlayState: WebFrontendOverlayState) {
        self.server = server

        overlayState.$currentPath
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                self?.currentPath = path
                self?.updateSelection()
            }
            .store(in: &cancellables)

        overlayState.$connectionState
            .filter(\.isReadyForDisplay)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.readLegacyPreferences()
            }
            .store(in: &cancellables)

        loadCachedPanels()
        rebuild()
    }

    deinit {
        tokens.forEach { $0.cancel() }
    }

    func start() {
        guard tokens.isEmpty, let connection = Current.api(for: server)?.connection else { return }

        tokens.append(connection.caches.panels.subscribe { [weak self] _, panels in
            Task { @MainActor [weak self] in
                self?.panels = panels.allPanels
                self?.rebuild()
            }
        })

        tokens.append(connection.caches.user.subscribe { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.user = user
                self?.rebuild()
            }
        })

        tokens.append(connection.subscribe(
            to: HATypedSubscription<FrontendSidebarUserData>.frontendUserData(key: FrontendSidebarUserData.userDataKey),
            initiated: { [weak self] result in
                guard case .failure = result else { return }
                // Older cores have no `frontend/subscribe_user_data`; fall back to a one-off fetch.
                Task { @MainActor [weak self] in
                    self?.fetchSidebarUserData(connection: connection)
                }
            },
            handler: { [weak self] _, userData in
                Task { @MainActor [weak self] in
                    self?.sidebarUserData = userData
                    self?.rebuild()
                }
            }
        ))

        tokens.append(connection.send(
            HATypedRequest<FrontendDefaultPanelData>.frontendUserData(key: FrontendDefaultPanelData.dataKey)
        ) { [weak self] result in
            guard case let .success(data) = result else { return }
            Task { @MainActor [weak self] in
                self?.coreUserData = data
                self?.rebuild()
            }
        })

        tokens.append(connection.send(
            HATypedRequest<FrontendDefaultPanelData>.frontendSystemData(key: FrontendDefaultPanelData.dataKey)
        ) { [weak self] result in
            guard case let .success(data) = result else { return }
            Task { @MainActor [weak self] in
                self?.systemDefaultPanel = data.defaultPanel
                self?.rebuild()
            }
        })

        tokens.append(connection.subscribe(
            to: HATypedSubscription<PersistentNotificationsMessage>(
                request: .init(type: "persistent_notification/subscribe")
            ),
            handler: { [weak self] _, message in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    notificationIds = message.apply(to: notificationIds)
                    rebuild()
                }
            }
        ))
    }

    func stop() {
        tokens.forEach { $0.cancel() }
        tokens = []
    }

    func select(itemId: String) {
        guard let item = (mainItems + fixedItems).first(where: { $0.id == itemId }) else { return }
        switch item.kind {
        case .notifications:
            onShowNotifications?()
        case .panel, .profile:
            if let path = item.navigationPath {
                onNavigate?(path)
            }
        }
    }

    // MARK: - Editing

    /// The frontend never lets the default panel be hidden.
    func canHide(_ item: MacSidebarItem) -> Bool {
        item.id != defaultPanelPath
    }

    /// Live reorder while dragging: moves `draggedId` to the slot of `targetId` without saving yet.
    func moveItem(_ draggedId: String, to targetId: String) {
        guard let from = mainItems.firstIndex(where: { $0.id == draggedId }),
              let to = mainItems.firstIndex(where: { $0.id == targetId }),
              from != to else { return }
        mainItems.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    func commitReorder() {
        save(effectiveUserData.reordered(to: mainItems.map(\.id)))
    }

    func hide(itemId: String) {
        guard let item = mainItems.first(where: { $0.id == itemId }), canHide(item) else { return }
        save(effectiveUserData.hiding(itemId, visibleOrder: mainItems.map(\.id)))
    }

    func show(itemId: String) {
        guard hiddenItems.contains(where: { $0.id == itemId }) else { return }
        save(effectiveUserData.showing(itemId, visibleOrder: mainItems.map(\.id)))
    }

    /// Mirrors the profile page's dashboard picker: only dashboards can be chosen, and the current
    /// default needs no action.
    func canSetDefaultDashboard(_ item: MacSidebarItem) -> Bool {
        item.isDashboard && item.id != defaultPanelPath
    }

    func setDefaultDashboard(itemId: String) {
        guard let item = (mainItems + hiddenItems).first(where: { $0.id == itemId }),
              canSetDefaultDashboard(item) else { return }
        coreUserData = coreUserData.settingDefaultPanel(itemId)
        rebuild()
        guard let connection = Current.api(for: server)?.connection else { return }
        tokens.append(connection.send(
            HATypedRequest<HAResponseVoid>.setFrontendUserData(
                key: FrontendDefaultPanelData.dataKey,
                value: coreUserData.rawValue
            )
        ) { result in
            if case let .failure(error) = result {
                Current.Log.error("Failed to save default dashboard: \(error)")
            }
        })
    }

    func resetToDefaults() {
        legacyPanelOrder = nil
        legacyHiddenPanels = nil
        save(FrontendSidebarUserData())
    }

    /// The preferences in effect, with the frontend's `localStorage` fallback applied.
    private var effectiveUserData: FrontendSidebarUserData {
        FrontendSidebarUserData(
            panelOrder: sidebarUserData.panelOrder ?? legacyPanelOrder,
            hiddenPanels: sidebarUserData.hiddenPanels ?? legacyHiddenPanels
        )
    }

    private func save(_ userData: FrontendSidebarUserData) {
        sidebarUserData = userData
        rebuild()
        guard let connection = Current.api(for: server)?.connection else { return }
        tokens.append(connection.send(
            HATypedRequest<HAResponseVoid>.setFrontendUserData(
                key: FrontendSidebarUserData.userDataKey,
                value: userData.encoded
            )
        ) { result in
            if case let .failure(error) = result {
                Current.Log.error("Failed to save sidebar user data: \(error)")
            }
        })
    }

    private func readLegacyPreferences() {
        guard let readLocalStorage else { return }
        for key in LegacyStorageKey.allCases {
            readLocalStorage(key.rawValue) { [weak self] value in
                Task { @MainActor [weak self] in
                    self?.applyLegacyPreference(key: key, rawValue: value)
                }
            }
        }
    }

    private func applyLegacyPreference(key: LegacyStorageKey, rawValue: String?) {
        let json = rawValue.flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) }
        switch key {
        case .panelOrder:
            legacyPanelOrder = json as? [String]
        case .hiddenPanels:
            legacyHiddenPanels = json as? [String]
        case .defaultPanel:
            legacyDefaultPanel = (json as? String).flatMap { $0.isEmpty ? nil : $0 }
        }
        rebuild()
    }

    private func fetchSidebarUserData(connection: HAConnection) {
        tokens.append(connection.send(
            HATypedRequest<FrontendSidebarUserData>.frontendUserData(key: FrontendSidebarUserData.userDataKey)
        ) { [weak self] result in
            guard case let .success(userData) = result else { return }
            Task { @MainActor [weak self] in
                self?.sidebarUserData = userData
                self?.rebuild()
            }
        })
    }

    private func loadCachedPanels() {
        do {
            panels = try AppPanel.panels(serverId: server.identifier.rawValue)?.map { panel in
                HAPanel(
                    icon: panel.icon,
                    title: panel.title,
                    path: panel.path,
                    component: panel.component,
                    showInSidebar: panel.showInSidebar,
                    rawTitle: panel.title == panel.path ? nil : panel.title
                )
            } ?? []
        } catch {
            Current.Log.error("Failed to load cached panels for native sidebar: \(error)")
        }
    }

    private func rebuild() {
        defaultPanelPath = MacSidebarItemsBuilder.resolveDefaultPanelPath(
            preferred: userDefaultPanel ?? systemDefaultPanel ?? legacyDefaultPanel,
            panels: panels
        )
        let userData = effectiveUserData
        mainItems = MacSidebarItemsBuilder.mainItems(
            panels: panels,
            defaultPanelPath: defaultPanelPath,
            panelOrder: userData.panelOrder ?? [],
            hiddenPanels: userData.hiddenPanels ?? []
        )
        hiddenItems = MacSidebarItemsBuilder.hiddenItems(
            panels: panels,
            defaultPanelPath: defaultPanelPath,
            panelOrder: userData.panelOrder ?? [],
            hiddenPanels: userData.hiddenPanels ?? []
        )
        fixedItems = MacSidebarItemsBuilder.fixedItems(
            panels: panels,
            isAdmin: user?.isAdmin ?? false,
            userName: user?.name,
            notificationsCount: notificationIds.count
        )
        updateSelection()
    }

    private func updateSelection() {
        let itemId = MacSidebarItemsBuilder.itemId(forPath: currentPath)
        let knownIds = Set((mainItems + fixedItems).map(\.id))
        selectedItemId = itemId.flatMap { knownIds.contains($0) ? $0 : nil }
    }
}
