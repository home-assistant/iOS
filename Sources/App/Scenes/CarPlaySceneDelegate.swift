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
    private var quickAccessListTemplate: any CarPlayTemplateProvider
    private var areasZonesListTemplate: any CarPlayTemplateProvider

    private var allTemplates: [any CarPlayTemplateProvider] {
        [quickAccessListTemplate, areasZonesListTemplate, domainsListTemplate, serversListTemplate]
    }

    private var cachedConfig: CarPlayConfig?

    override init() {
        self.domainsListTemplate = CarPlayDomainsListTemplate.build()
        self.serversListTemplate = CarPlayServersListTemplate.build()
        self.quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
        self.areasZonesListTemplate = CarPlayAreasZonesTemplate.build()
        super.init()
    }

    private func setTemplates() {
        var visibleTemplates = allTemplates

        // In case config exists, we will only show the tabs that are enabled
        if let config = CarPlayConfig.getConfig() {
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
