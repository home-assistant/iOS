import CarPlay
import Communicator
import HAKit
import PromiseKit
import Shared

public protocol EntitiesStateSubscription {
    func subscribe()
    func unsubscribe()
}

@available(iOS 16.0, *)
class CarPlaySceneDelegate: UIResponder {
    private var interfaceController: CPInterfaceController?
    private var entities: HACache<HACachedStates>?
    private var entitiesSubscriptionToken: HACancellable?

    private var domainsListTemplate: any CarPlayTemplateProvider
    private var serversListTemplate: any CarPlayTemplateProvider
    private var quickAccessListTemplate: any CarPlayTemplateProvider
    private var areasZonesListTemplate: any CarPlayTemplateProvider

    private var allTemplates: [any CarPlayTemplateProvider] {
        [quickAccessListTemplate, areasZonesListTemplate, domainsListTemplate, serversListTemplate]
    }

    private var cachedConfig: CarPlayConfig?
    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    override init() {
        self.domainsListTemplate = CarPlayDomainsListTemplate.build()
        self.serversListTemplate = CarPlayServersListTemplate.build()
        self.quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
        self.areasZonesListTemplate = CarPlayAreasZonesTemplate.build()
        super.init()
    }

    private func setTemplates() {
        var visibleTemplates = allTemplates

        do {
            // In case config exists, we will only show the tabs that are enabled
            if let config = try CarPlayConfig.config() {
                guard config != cachedConfig else { return }
                cachedConfig = config
                visibleTemplates = config.tabs.map {
                    switch $0 {
                    case .quickAccess:
                        // Reload the quick access list template
                        quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
                        return quickAccessListTemplate
                    case .areas:
                        return areasZonesListTemplate
                    case .domains:
                        return domainsListTemplate
                    case .settings:
                        return serversListTemplate
                    }
                }
            }
        } catch {
            Current.Log.error("Error fetching CarPlay config \(error)")
        }

        let tabBar = CPTabBarTemplate(templates: visibleTemplates.map { templateProvider in
            templateProvider.template
        })
        setInterfaceControllerForChildren()
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        updateTemplates()
    }

    private func setInterfaceControllerForChildren() {
        domainsListTemplate.interfaceController = interfaceController
        serversListTemplate.interfaceController = interfaceController
        quickAccessListTemplate.interfaceController = interfaceController
        areasZonesListTemplate.interfaceController = interfaceController
    }

    @objc private func updateTemplates() {
        allTemplates.forEach { $0.update() }
    }

    private func subscribeToEntitiesChanges() {
        let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first

        guard let server, entitiesSubscriptionToken == nil else { return }
        entities = Current.api(for: server).connection.caches.states
        entitiesSubscriptionToken?.cancel()
        entitiesSubscriptionToken = entities?.subscribe { [weak self] _, states in
            self?.allTemplates.forEach {
                $0.entitiesStateChange(entities: states)
            }
        }
    }
}

// MARK: - CPTemplateApplicationSceneDelegate

@available(iOS 16.0, *)
extension CarPlaySceneDelegate: CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.interfaceController?.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTemplates),
            name: HAConnectionState.didTransitionToStateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateTemplates),
            name: HomeAssistantAPI.didConnectNotification,
            object: nil
        )

        setTemplates()
        subscribeToEntitiesChanges()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        NotificationCenter.default.removeObserver(self)
    }
}

@available(iOS 16.0, *)
extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach { $0.templateWillDisappear(template: aTemplate) }
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach { $0.templateWillAppear(template: aTemplate) }
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        setTemplates()
    }
}
