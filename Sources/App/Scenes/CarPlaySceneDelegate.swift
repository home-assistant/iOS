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
    private let realm = Current.realm()

    private var domainsListTemplate: CarPlayTemplateProvider?
    private var serversListTemplate: CarPlayTemplateProvider?
    private var actionsListTemplate: CarPlayTemplateProvider?

    @objc private func updateTemplates() {
        setupDomainListTemplate()
        setupActionsTemplate()
        setupServerListTemplate()
        let templates: [CPTemplate] = [
            actionsListTemplate?.template,
            domainsListTemplate?.template,
            serversListTemplate?.template,
        ].compactMap({ $0 })
        let tabBar = CPTabBarTemplate(templates: templates)
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
    }

    private func setupDomainListTemplate() {
        domainsListTemplate = CarPlayDomainsListTemplate()
        domainsListTemplate?.interfaceController = interfaceController
        domainsListTemplate?.update()
    }

    private func setupActionsTemplate() {
        let actions = realm.objects(Action.self)
            .sorted(byKeyPath: "Position")
            .filter("Scene == nil")

        let actionsListTemplate = CarPlayActionsTemplate(actions: actions)
        self.actionsListTemplate = actionsListTemplate
        actionsListTemplate.update()
    }

    private func setupServerListTemplate() {
        let serversListTemplate = CarPlayServersListTemplate()
        serversListTemplate.interfaceController = interfaceController
        serversListTemplate.update()
        self.serversListTemplate = serversListTemplate
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

        updateTemplates()
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
        domainsListTemplate?.templateWillDisappear(template: aTemplate)
        actionsListTemplate?.templateWillDisappear(template: aTemplate)
        serversListTemplate?.templateWillDisappear(template: aTemplate)
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        domainsListTemplate?.templateWillAppear(template: aTemplate)
        actionsListTemplate?.templateWillAppear(template: aTemplate)
        serversListTemplate?.templateWillAppear(template: aTemplate)
    }
}
