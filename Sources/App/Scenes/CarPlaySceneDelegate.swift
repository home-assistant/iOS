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
    private var entities: HACache<Set<HAEntity>>?

    private var domainsListTemplate: any CarPlayTemplateProvider
    private var serversListTemplate: any CarPlayTemplateProvider
    private var actionsListTemplate: any CarPlayTemplateProvider
    private var areasZonesListTemplate: any CarPlayTemplateProvider

    private var allTemplates: [any CarPlayTemplateProvider] {
        [actionsListTemplate, areasZonesListTemplate, domainsListTemplate, serversListTemplate]
    }

    private var cachedConfig: CarPlayConfig?

    override init() {
        self.domainsListTemplate = CarPlayDomainsListTemplate.build()
        self.serversListTemplate = CarPlayServersListTemplate.build()
        self.actionsListTemplate = CarPlayQuickAccessTemplate.build()
        self.areasZonesListTemplate = CarPlayAreasZonesTemplate.build()
        super.init()
    }

    private func setTemplates() {
        var visibleTemplates = allTemplates

        // In case config exists, we will only show the tabs that are enabled
        if let config = getConfig() {
            guard config != cachedConfig else { return }
            cachedConfig = config
            visibleTemplates = config.tabs.map {
                switch $0 {
                case .quickAccess:
                    return actionsListTemplate
                case .areas:
                    return areasZonesListTemplate
                case .domains:
                    return domainsListTemplate
                case .settings:
                    return serversListTemplate
                }
            }
        }

        let tabBar = CPTabBarTemplate(templates: visibleTemplates.map { templateProvider in
            templateProvider.template
        })
        setInterfaceControllerForChildren()
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        updateTemplates()
    }

    @MainActor
    private func getConfig() -> CarPlayConfig? {
        do {
            if let config: CarPlayConfig = try Current.database().read({ db in
                do {
                    return try CarPlayConfig.fetchOne(db)
                } catch {
                    Current.Log.error("Error fetching CarPlay config \(error)")
                }
                return nil
            }) {
                Current.Log.info("CarPlay configuration exists, using it in CarPlay")
                return config
            } else {
                Current.Log.error("No CarPlay config found when CarPlay started")
                return nil
            }
        } catch {
            Current.Log.error("Failed to access database (GRDB) in CarPlay, error: \(error.localizedDescription)")
            return nil
        }
    }

    private func setInterfaceControllerForChildren() {
        domainsListTemplate.interfaceController = interfaceController
        serversListTemplate.interfaceController = interfaceController
        actionsListTemplate.interfaceController = interfaceController
        areasZonesListTemplate.interfaceController = interfaceController
    }

    @objc private func updateTemplates() {
        allTemplates.forEach { $0.update() }
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
