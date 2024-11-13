import CarPlay
import Combine
import Communicator
import GRDB
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
    private var entitiesSubscriptionToken: HACancellable?

    private var domainsListTemplate: (any CarPlayTemplateProvider)?
    private var serversListTemplate: (any CarPlayTemplateProvider)?
    private var quickAccessListTemplate: (any CarPlayTemplateProvider)?
    private var areasZonesListTemplate: (any CarPlayTemplateProvider)?

    private var allTemplates: [any CarPlayTemplateProvider] {
        [
            quickAccessListTemplate,
            areasZonesListTemplate,
            domainsListTemplate,
            serversListTemplate
        ].compactMap({$0})
    }

    private var cachedConfig: CarPlayConfig?
    private var configObservation: AnyDatabaseCancellable?

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    func setup() {
        observeCarPlayConfigChanges()
        subscribeToEntitiesChanges()
    }

    private func setTemplates(config: CarPlayConfig?) {
        var visibleTemplates: [any CarPlayTemplateProvider] = []
        if let config {
            guard config != cachedConfig else { return }
            cachedConfig = config
            visibleTemplates = config.tabs.compactMap {
                switch $0 {
                case .quickAccess:
                    quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
                    return quickAccessListTemplate
                case .areas:
                    areasZonesListTemplate = CarPlayAreasZonesTemplate.build()
                    return areasZonesListTemplate
                case .domains:
                    domainsListTemplate = CarPlayDomainsListTemplate.build()
                    return domainsListTemplate
                case .settings:
                    serversListTemplate = CarPlayServersListTemplate.build()
                    // So it can reload in case of server changes
                    (serversListTemplate as? CarPlayServersListTemplate)?.sceneDelegate = self
                    return serversListTemplate
                }
            }
        } else {
            quickAccessListTemplate = CarPlayQuickAccessTemplate.build()
            visibleTemplates = [quickAccessListTemplate].compactMap({$0})
        }

        let tabBar = CPTabBarTemplate(templates: visibleTemplates.map { templateProvider in
            templateProvider.template
        })
        setInterfaceControllerForChildren()
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        updateTemplates()
    }

    private func setInterfaceControllerForChildren() {
        domainsListTemplate?.interfaceController = interfaceController
        serversListTemplate?.interfaceController = interfaceController
        quickAccessListTemplate?.interfaceController = interfaceController
        areasZonesListTemplate?.interfaceController = interfaceController
    }

    @objc private func updateTemplates() {
        allTemplates.forEach { $0.update() }
    }

    private func subscribeToEntitiesChanges() {
        guard let server = Current.servers.server(forServerIdentifier: preferredServerId) ?? Current.servers.all.first else { return }
        entitiesSubscriptionToken?.cancel()
        entitiesSubscriptionToken = Current.api(for: server).connection.caches.states.subscribe { [weak self] _, states in
            self?.allTemplates.forEach {
                $0.entitiesStateChange(entities: states)
            }
        }
    }

    private func observeCarPlayConfigChanges() {
        configObservation?.cancel()
        let observation = ValueObservation.tracking(CarPlayConfig.fetchOne)
        configObservation = observation.start(
            in: Current.database,
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

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach { $0.templateWillDisappear(template: aTemplate) }
    }

    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        allTemplates.forEach { $0.templateWillAppear(template: aTemplate) }
    }
}
