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
class CarPlayDelegate: UIResponder {
    public static let SUPPORTED_DOMAINS_WITH_STRING = [
        "button": L10n.Carplay.Labels.buttons,
        "cover": L10n.Carplay.Labels.covers,
        "input_boolean": L10n.Carplay.Labels.inputBooleans,
        "input_button": L10n.Carplay.Labels.inputButtons,
        "light": L10n.Carplay.Labels.lights,
        "lock": L10n.Carplay.Labels.locks,
        "scene": L10n.Carplay.Labels.scenes,
        "script": L10n.Carplay.Labels.scripts,
        "switch": L10n.Carplay.Labels.switches
    ]
    
    public let SUPPORTED_DOMAINS = SUPPORTED_DOMAINS_WITH_STRING.keys
    
    private var MAP_DOMAINS = [
        "device_tracker",
        "person",
        "sensor",
        "zone"
    ]
    
    private var interfaceController: CPInterfaceController?
    private var filteredEntities: [HAEntity] = []
    private var entitiesGridTemplate: EntitiesGridTemplate?
    private var domainsListTemplate: DomainsListTemplate?
    private var entitiesStateSubscribeCancelable: HACancellable?
    private var serverObserver: HACancellable?
    private var serverId: Identifier<Server>? {
        didSet {
            loadEntities()
        }
    }
    
    let prefs = UserDefaults(suiteName: Constants.AppGroupID)!
    
    func loadEntities() {
        self.domainsListTemplate?.setServerListButton(show: Current.servers.all.count > 1)
        
        guard let serverId = serverId, let server = Current.servers.server(for: serverId) else {
            Current.Log.info("No server available to get entities")
            filteredEntities.removeAll()
            self.domainsListTemplate?.entitiesUpdate(updateEntities: filteredEntities)
            return
        }
        
        guard let allServerEntities = Current.api(for: server).connection.caches.states.value?.all else {
            Current.Log.info("No entities available from server \(server.info.name)")
            filteredEntities.removeAll()
            self.domainsListTemplate?.entitiesUpdate(updateEntities: filteredEntities)
            interfaceController?.setRootTemplate(self.domainsListTemplate!.getTemplate(), animated: false)
            return
        }
        
        filteredEntities = getFilteredAndSortEntities(entities: Array(allServerEntities))
        self.domainsListTemplate?.entitiesUpdate(updateEntities: filteredEntities)
        if let template = self.domainsListTemplate?.getTemplate() {
            interfaceController?.setRootTemplate(template, animated: false)
        }
    }
    
    func getFilteredAndSortEntities(entities: [HAEntity]) -> [HAEntity] {
        var tmpEntities: [HAEntity] = []
        
        for entity in entities where SUPPORTED_DOMAINS.contains(entity.domain) {
            tmpEntities.append(entity)
        }
        return tmpEntities.sorted(by: {$0.getLocalizedState() < $1.getLocalizedState()})
    }
    
    func setServer(server: Server) {
        serverId = server.identifier
        serverObserver = server.observe { [weak self] _ in
            self?.connectionInfoDidChange()
        }

        entitiesStateSubscribeCancelable?.cancel()
        prefs.set(server.identifier.rawValue, forKey: "carPlay-server")
        subscribeEntitiesUpdates(for: server)
    }
    
    @objc private func connectionInfoDidChange() {
        DispatchQueue.main.async {
            self.domainsListTemplate?.setServerListButton(show: Current.servers.all.count > 1)
            if self.serverId == nil {
                ///No server is selected
                guard let server = Current.servers.getServer() else {
                    Current.Log.info("No server connected")
                    return
                }
                self.setServer(server: server)
            }
        }
    }
    
    func subscribeEntitiesUpdates(for server: Server) {
        Current.Log.info("Subscribe for entities update at server \(server.info.name)")
        entitiesStateSubscribeCancelable?.cancel()
        entitiesStateSubscribeCancelable = Current.api(for: server).connection.caches.states.subscribe { [weak self] cancellable, cachedStates in
            Current.Log.info("Received entities update of server \(server.info.name)")
            guard let self = self else {
                cancellable.cancel()
                return
            }

            self.loadEntities()
        }
    }
    
    //Templates
    
    func showNoServerAlert() {
        guard self.interfaceController?.presentedTemplate == nil else {
            return
        }
        
        let loginAlertAction: CPAlertAction = CPAlertAction(title: L10n.Carplay.Labels.alreadyAddedServer, style: .default) { _ in
            if !Current.servers.all.isEmpty {
                self.interfaceController?.dismissTemplate(animated: true)
            }
        }
        let alertTemplate = CPAlertTemplate(titleVariants: [L10n.Carplay.Labels.noServersAvailable], actions: [loginAlertAction])
        self.interfaceController?.presentTemplate(alertTemplate, animated: true)
    }
    
    func setDomainListTemplate() {
        domainsListTemplate = DomainsListTemplate(title: L10n.About.Logo.appTitle, entities: filteredEntities, ic: interfaceController!,
                                                listItemHandler: {[weak self] domain, entities in
            
            guard let self = self, let server = Current.servers.getServer(id: self.serverId) else {
                return
            }
            
            let itemTitle = CarPlayDelegate.SUPPORTED_DOMAINS_WITH_STRING[domain] ?? domain
            self.entitiesGridTemplate = EntitiesGridTemplate(title: itemTitle, domain: domain, server: server, entities: entities)
            self.interfaceController?.pushTemplate(self.entitiesGridTemplate!.getTemplate(), animated: true)
        }, serverButtonHandler: { _ in
            self.setServerListTemplate()
        })
        
        interfaceController?.setRootTemplate(domainsListTemplate!.getTemplate(), animated: true)
    }
    
    func setServerListTemplate() {
        var serverList: [CPListItem] = []
        for server in Current.servers.all {
            let serverItem = CPListItem(text: server.info.name, detailText: "\(server.info.connection.activeURLType.description) - \(server.info.connection.activeURL().absoluteString)")
            serverItem.handler = { [weak self] item, completion in
                self?.setServer(server: server)
                if let templates = self?.interfaceController?.templates, templates.count > 1 {
                    self?.interfaceController?.popTemplate(animated: true)
                }
                completion()
            }
            serverItem.accessoryType = self.serverId == server.identifier ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList)
        let serverListTemplate = CPListTemplate(title: L10n.Carplay.Labels.servers, sections: [section])
        self.interfaceController?.pushTemplate(serverListTemplate, animated: true)
    }
}

@available(iOS 16.0, *)
extension CarPlayDelegate: CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        self.interfaceController?.delegate = self
        
        /// Observer for servers list changes
        Current.servers.add(observer: self)
        
        setDomainListTemplate()
        
        if Current.servers.all.isEmpty {
            showNoServerAlert()
        }
        
        if Current.servers.isConnected() {
            if let serverIdentifier = prefs.string(forKey: "carPlay-server"),
               let selectedServer = Current.servers.server(forServerIdentifier: serverIdentifier) {
                setServer(server: selectedServer)
            } else if let server = Current.servers.getServer() {
                setServer(server: server)
            }
        }
                
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionInfoDidChange),
            name: HAConnectionState.didTransitionToStateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(connectionInfoDidChange),
            name: HomeAssistantAPI.didConnectNotification,
            object: nil
        )
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow) {
        entitiesStateSubscribeCancelable?.cancel()
        entitiesStateSubscribeCancelable = nil
        NotificationCenter.default.removeObserver(self)
        Current.servers.remove(observer: self)
        serverObserver?.cancel()
        serverObserver = nil
    }
}

@available(iOS 16.0, *)
extension CarPlayDelegate: CPInterfaceControllerDelegate {
    
    func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool) {
        if aTemplate == entitiesGridTemplate?.getTemplate() {
            entitiesGridTemplate?.subscribe()
        }
    }

    func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool) {
        if aTemplate == entitiesGridTemplate?.getTemplate() {
            entitiesGridTemplate?.unsubscribe()
        }
    }
}

@available(iOS 16.0, *)
extension CarPlayDelegate: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        self.domainsListTemplate?.setServerListButton(show: Current.servers.all.count > 1)
        
        if Current.servers.getServer(id: serverId) == nil {
            serverId = nil
        }
        if serverId == nil, let server = Current.servers.getServer() {
            setServer(server: server)
        }
        if serverManager.all.isEmpty {
            entitiesStateSubscribeCancelable?.cancel()
            entitiesStateSubscribeCancelable = nil
            showNoServerAlert()
        } else if self.interfaceController?.presentedTemplate != nil {
            self.interfaceController?.dismissTemplate(animated: true)
        }
    }
}
