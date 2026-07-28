import CarPlay
import Combine
import GRDB
import HAKit
import PromiseKit
import Shared

class CarPlaySceneDelegate: UIResponder {
    private var interfaceController: CPInterfaceController?
    private var entitiesSubscriptionToken: HACancellable?
    private var quickAccessEntitiesSubscriptionTokens: [HACancellable?] = []

    private var domainsListTemplate: (any CarPlayTemplateProvider)?
    private var serversListTemplate: (any CarPlayTemplateProvider)?
    private var quickAccessListTemplate: (any CarPlayTemplateProvider)?
    private var areasZonesListTemplate: (any CarPlayTemplateProvider)?
    /// Quick Access folders promoted to their own tab, keyed by folder id.
    private var folderTabTemplates: [String: any CarPlayTemplateProvider] = [:]
    private var includedDomains: [Domain] = Domain.carPlaySupported

    private var allTemplates: [any CarPlayTemplateProvider] {
        [
            quickAccessListTemplate,
            areasZonesListTemplate,
            domainsListTemplate,
            serversListTemplate,
        ].compactMap({ $0 }) + Array(folderTabTemplates.values)
    }

    /// Templates fed by the Quick Access per-server entity subscriptions: the Quick Access tab and
    /// every folder tab (folder items live inside the Quick Access configuration).
    private var quickAccessStateTemplates: [any CarPlayTemplateProvider] {
        [quickAccessListTemplate].compactMap({ $0 }) + Array(folderTabTemplates.values)
    }

    private var cachedConfig: CarPlayConfig?
    private var configObservation: AnyDatabaseCancellable?
    private var latestStates: HACachedStates?
    private var latestStatesServerId: String?
    private var latestQuickAccessStatesPerServer: [String: HACachedStates] = [:]
    private var quickAccessSubscriptionKey: [String: [String]] = [:]

    deinit {
        entitiesSubscriptionToken?.cancel()
        quickAccessEntitiesSubscriptionTokens.forEach({ $0?.cancel() })
    }

    func setup() {
        observeCarPlayConfigChanges()
        subscribeToEntitiesChanges()
    }

    private func setTemplates(config: CarPlayConfig?) {
        var visibleTemplates: [any CarPlayTemplateProvider] = []
        if let config {
            subscribeToQuickAccessEntitiesChanges(configEntities: config.quickAccessItems)
            guard hasConfigChanged(config, comparedTo: cachedConfig) else { return }
            let previousTabs = cachedConfig?.tabs
            let previousFolderTabSignature = folderTabSignature(config: cachedConfig)
            cachedConfig = config

            // Content-only changes (quick access items, layout, add/edit visibility) don't alter the tab
            // structure, so refresh the existing providers instead of replacing the root template. Replacing
            // the root mid-transition (e.g. while the in-car add item flow is dismissing its confirmation and
            // popping back) fails silently and leaves the CarPlay screen blank. Folder tabs bake their name
            // and icon into the tab bar, so a change to those requires a rebuild too.
            if previousTabs == config.tabs, previousFolderTabSignature == folderTabSignature(config: config) {
                updateTemplates()
                return
            }

            // Tabs can be removed from the configuration while their template instances are still
            // cached on the scene delegate. Clear those references before rebuilding so hidden
            // tabs stop receiving replays and state updates through `allTemplates`.
            if !config.tabs.contains(.quickAccess) {
                quickAccessListTemplate = nil
            }
            if !config.tabs.contains(.areas) {
                areasZonesListTemplate = nil
            }
            if !config.tabs.contains(.domains) {
                domainsListTemplate = nil
            }
            if !config.tabs.contains(.settings) {
                serversListTemplate = nil
            }
            // Folder tabs always rebuild so they pick up the folder's current name and icon.
            folderTabTemplates = [:]

            visibleTemplates = config.tabs.compactMap {
                switch $0 {
                case .quickAccess:
                    buildQuickAccessTab()
                    return quickAccessListTemplate
                case .areas:
                    areasZonesListTemplate = CarPlayAreasZonesTemplate.build()
                    return areasZonesListTemplate
                case .domains:
                    domainsListTemplate = CarPlayDomainsListTemplate.build()
                    return domainsListTemplate
                case .settings:
                    buildServerTab()
                    return serversListTemplate
                case let .folder(folderId):
                    guard let folder = config.folder(withId: folderId) else {
                        Current.Log.error("CarPlay folder tab references missing folder \(folderId); skipping tab")
                        return nil
                    }
                    let provider = CarPlayQuickAccessTemplate.buildFolderTab(folder: folder)
                    folderTabTemplates[folderId] = provider
                    return provider
                }
            }
        } else {
            subscribeToQuickAccessEntitiesChanges(configEntities: [])
            // The no-config tab set below differs from any stored config's tabs; clear the cache so a config
            // appearing later always rebuilds instead of matching a stale tab comparison.
            cachedConfig = nil
            folderTabTemplates = [:]
            buildQuickAccessTab()
            buildServerTab()
            visibleTemplates = allTemplates
        }

        // CarPlay rejects tab bars with more templates than the system maximum.
        let maximumTabCount = CPTabBarTemplate.maximumTabCount
        if visibleTemplates.count > maximumTabCount {
            Current.Log
                .error("CarPlay tab count \(visibleTemplates.count) exceeds maximum \(maximumTabCount); truncating")
            let hiddenTemplates = visibleTemplates.suffix(visibleTemplates.count - maximumTabCount)
            visibleTemplates = Array(visibleTemplates.prefix(maximumTabCount))
            folderTabTemplates = folderTabTemplates.filter { _, provider in
                !hiddenTemplates.contains(where: { $0.template == provider.template })
            }
        }

        let tabBar = CPTabBarTemplate(templates: visibleTemplates.map { templateProvider in
            templateProvider.template
        })
        setInterfaceControllerForChildren()
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        updateTemplates()
        // The selected-server subscription may already have usable data when tabs are rebuilt.
        // Replay it so controls/areas do not flash empty while waiting for the next cache event.
        replaySelectedServerStates()
        // Folder tabs consume the quick access per-server snapshots; replay them so freshly built
        // folder tabs don't flash empty entity rows.
        replayQuickAccessStates()
    }

    /// `CarPlayConfig`'s synthesized equality compares `MagicItem`s by identity only, which misses
    /// content edits such as items added inside a folder or customization changes. Compare item
    /// content hashes as well so those edits refresh the templates live.
    private func hasConfigChanged(_ config: CarPlayConfig, comparedTo cached: CarPlayConfig?) -> Bool {
        guard let cached else { return true }
        return config != cached
            || config.quickAccessItems.map(\.contentHash) != cached.quickAccessItems.map(\.contentHash)
    }

    /// Signature of the folder tabs' display metadata (name/icon), which is baked into the tab bar
    /// at build time and therefore requires a rebuild when it changes.
    private func folderTabSignature(config: CarPlayConfig?) -> [String] {
        guard let config else { return [] }
        return config.tabs.compactMap(\.folderId).map { folderId in
            let folder = config.folder(withId: folderId)
            return [
                folderId,
                folder?.displayText ?? "",
                folder?.customization?.icon ?? "",
            ].joined(separator: "|")
        }
    }

    private func buildQuickAccessTab() {
        quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
        // Quick access keeps a separate per-server cache for its mixed-server entities,
        // so restore that snapshot immediately when the template is recreated.
        replayQuickAccessStates()
    }

    private func buildServerTab() {
        serversListTemplate = CarPlayServersListTemplate.build()
        // So it can reload in case of server changes
        (serversListTemplate as? CarPlayServersListTemplate)?.sceneDelegate = self
    }

    private func setInterfaceControllerForChildren() {
        domainsListTemplate?.interfaceController = interfaceController
        serversListTemplate?.interfaceController = interfaceController
        quickAccessListTemplate?.interfaceController = interfaceController
        areasZonesListTemplate?.interfaceController = interfaceController
        for var folderTemplate in folderTabTemplates.values {
            folderTemplate.interfaceController = interfaceController
        }
    }

    @objc private func updateTemplates() {
        allTemplates.forEach { $0.update() }
    }

    private func subscribeToEntitiesChanges() {
        guard let server = CarPlayPreferredServer.current else { return }
        entitiesSubscriptionToken?.cancel()
        latestStates = nil
        latestStatesServerId = nil

        var filter: [String: Any] = [:]
        if server.info.version > .canSubscribeEntitiesChangesWithFilter {
            filter = [
                "include": [
                    "domains": includedDomains.map(\.rawValue),
                ],
            ]
        }

        // Guarantee fresh data
        Current.api(for: server)?.connection.disconnect()
        entitiesSubscriptionToken = Current.api(for: server)?.connection.caches.states(filter)
            .subscribe { [weak self] _, states in
                self?.latestStates = states
                self?.latestStatesServerId = server.identifier.rawValue
                self?.allTemplates.forEach {
                    $0.entitiesStateChange(serverId: server.identifier.rawValue, entities: states)
                }
            }
    }

    // Quick access entities may not be from the same server that is selected as default in CarPlay
    private func subscribeToQuickAccessEntitiesChanges(configEntities: [MagicItem]) {
        // Folder items live one level deep; include their children so entities inside folders
        // (rendered in folder tabs and pushed folder lists) receive state updates too.
        let entityItems = configEntities
            .flatMap { [$0] + ($0.items ?? []) }
            .filter({ $0.type == .entity })
        let entityItemsByServer = Dictionary(grouping: entityItems, by: \.serverId)
        let subscriptionKey = entityItemsByServer.mapValues { items in
            Array(Set(items.map(\.id))).sorted()
        }

        guard subscriptionKey != quickAccessSubscriptionKey else {
            replayQuickAccessStates()
            return
        }

        quickAccessSubscriptionKey = subscriptionKey
        quickAccessEntitiesSubscriptionTokens.forEach({ $0?.cancel() })
        quickAccessEntitiesSubscriptionTokens = []

        guard !entityItems.isEmpty else {
            Current.Log.info("No quick access entities to subscribe to")
            latestQuickAccessStatesPerServer = [:]
            return
        }

        let servers = Set(entityItemsByServer.keys)
        latestQuickAccessStatesPerServer = latestQuickAccessStatesPerServer.filter { servers.contains($0.key) }

        entityItemsByServer.forEach { serverId, serverEntityItems in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else { return }
            guard let api = Current.api(for: server) else {
                Current.Log
                    .error("No API available to subscribe to CarPlay quick access entities for server \(serverId)")
                return
            }

            var filter: [String: Any] = [:]
            if server.info.version > .canSubscribeEntitiesChangesWithFilter {
                filter = [
                    "include": [
                        "entities": serverEntityItems.map(\.id),
                    ],
                ]
            }

            api.connectWebSocketIfNeeded()
            quickAccessEntitiesSubscriptionTokens.append(
                api.connection.caches.states(filter)
                    .subscribe { [weak self] _, states in
                        self?.latestQuickAccessStatesPerServer[serverId] = states
                        self?.quickAccessStateTemplates.forEach {
                            $0.entitiesStateChange(serverId: serverId, entities: states)
                        }
                    }
            )
        }
    }

    private func replayQuickAccessStates() {
        for (serverId, states) in latestQuickAccessStatesPerServer {
            quickAccessStateTemplates.forEach { $0.entitiesStateChange(serverId: serverId, entities: states) }
        }
    }

    private func replaySelectedServerStates() {
        guard let latestStates, let latestStatesServerId else { return }

        [
            areasZonesListTemplate,
            domainsListTemplate,
            serversListTemplate,
        ].compactMap({ $0 }).forEach {
            $0.entitiesStateChange(serverId: latestStatesServerId, entities: latestStates)
        }
    }

    private func observeCarPlayConfigChanges() {
        configObservation?.cancel()
        let observation = ValueObservation.tracking { db in
            try CarPlayConfig.fetchOne(db)
        }
        configObservation = observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("CarPlay config observation failed with error: \(error)")
            },
            onChange: { [weak self] carPlayConfig in
                // Observation uses main queue https://swiftpackageindex.com/groue/grdb.swift/v6.29.3/documentation/grdb/valueobservation#ValueObservation-Scheduling
                self?.setTemplates(config: carPlayConfig)
            }
        )
    }
}

// MARK: - CPTemplateApplicationSceneDelegate

extension CarPlaySceneDelegate: CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.interfaceController?.delegate = self
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        setup()
    }
}

extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach { $0.templateWillDisappear(template: aTemplate) }
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        if quickAccessStateTemplates.contains(where: { $0.template == aTemplate }) {
            replayQuickAccessStates()
        }
        if domainsListTemplate?.template == aTemplate || areasZonesListTemplate?.template == aTemplate {
            // Navigating back to controls/areas does not guarantee a fresh websocket emission.
            // Reusing the latest selected-server snapshot keeps those tabs populated.
            replaySelectedServerStates()
        }
        allTemplates.forEach { $0.templateWillAppear(template: aTemplate) }
    }
}
