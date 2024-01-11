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

    private let domainsListTemplate: CarPlayTemplateProvider
    private let serversListTemplate: CarPlayTemplateProvider
    private let actionsListTemplate: CarPlayTemplateProvider
    private let areasZonesListTemplate: CarPlayTemplateProvider

    private var allTemplates: [CarPlayTemplateProvider] {
        [actionsListTemplate, areasZonesListTemplate, domainsListTemplate, serversListTemplate]
    }

    override init() {
        self.domainsListTemplate = CarPlayDomainsListTemplate()
        self.serversListTemplate = CarPlayServersListTemplate()
        self.actionsListTemplate = CarPlayActionsTemplate()
        self.areasZonesListTemplate = CarPlayAreasZonesTemplate()
        super.init()
    }

    private func setTemplates() {
        let tabBar = CPTabBarTemplate(templates: allTemplates.map { $0.template })
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        updateTemplates()
    }

    @objc private func updateTemplates() {
        allTemplates.forEach { $0.update() }
    }

    private func setEmptyTemplate(interfaceController: CPInterfaceController?) {
        interfaceController?.setRootTemplate(CPInformationTemplate(
            title: L10n.About.Logo.title,
            layout: .leading,
            items: [],
            actions: []
        ), animated: true, completion: nil)
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
        allTemplates.forEach {$0.templateWillDisappear(template: aTemplate)}
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach {$0.templateWillDisappear(template: aTemplate)}
    }
}
