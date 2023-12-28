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
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
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
            interfaceController?.setRootTemplate(self.domainsListTemplate!.getTemplate(), animated: false, completion: nil)
            return
        }
        
        filteredEntities = getFilteredAndSortEntities(entities: Array(allServerEntities))
        self.domainsListTemplate?.entitiesUpdate(updateEntities: filteredEntities)
        if let template = self.domainsListTemplate?.getTemplate() {
            interfaceController?.setRootTemplate(template, animated: false, completion: nil)
        }
    }
    
    func getFilteredAndSortEntities(entities: [HAEntity]) -> [HAEntity] {
        var tmpEntities: [HAEntity] = []
        
        for entity in entities where CarPlayDomain(domain: entity.domain).isSupported {
            tmpEntities.append(entity)
        }
        return tmpEntities
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
                self.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }
        let alertTemplate = CPAlertTemplate(titleVariants: [L10n.Carplay.Labels.noServersAvailable], actions: [loginAlertAction])
        self.interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }
    
    func setDomainListTemplate() {
        domainsListTemplate = DomainsListTemplate(title: L10n.About.Logo.appTitle, entities: filteredEntities, ic: interfaceController!,
                                                listItemHandler: {[weak self] domain, entities in
            
            guard let self = self, let server = Current.servers.getServer(id: self.serverId) else {
                return
            }
            
            let itemTitle = CarPlayDomain(domain: domain).localizedDescription
            self.entitiesGridTemplate = EntitiesGridTemplate(title: itemTitle, domain: domain, server: server, entities: entities)
            self.interfaceController?.pushTemplate(self.entitiesGridTemplate!.getTemplate(), animated: true, completion: nil)
        }, serverButtonHandler: { _ in
            self.setServerListTemplate()
        })
        
        interfaceController?.setRootTemplate(domainsListTemplate!.getTemplate(), animated: true, completion: nil)
    }
    
    func setServerListTemplate() {
        var serverList: [CPListItem] = []
        for server in Current.servers.all {
            let serverItem = CPListItem(text: server.info.name, detailText: "\(server.info.connection.activeURLType.description) - \(server.info.connection.activeURL().absoluteString)")
            serverItem.handler = { [weak self] item, completion in
                self?.setServer(server: server)
                if let templates = self?.interfaceController?.templates, templates.count > 1 {
                    self?.interfaceController?.popTemplate(animated: true, completion: nil)
                }
                completion()
            }
            serverItem.accessoryType = self.serverId == server.identifier ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList)
        let serverListTemplate = CPListTemplate(title: L10n.Carplay.Labels.servers, sections: [section])
        self.interfaceController?.pushTemplate(serverListTemplate, animated: true, completion: nil)
    }
//}

//@available(iOS 16.0, *)
//extension CarPlaySceneDelegate: CPTemplateApplicationSceneDelegate {
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
extension CarPlaySceneDelegate: CPInterfaceControllerDelegate {
    
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
extension CarPlaySceneDelegate: ServerObserver {
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
            self.interfaceController?.dismissTemplate(animated: true, completion: nil)
        }
    }
}

enum CarPlayDomain: CaseIterable {
    case button
    case cover
    case input_boolean
    case input_button
    case light
    case lock
    case scene
    case script
    case switch_button
    case unsupported

    var domain: String {
        switch self {
        case .button: return "button"
        case .cover: return "cover"
        case .input_boolean: return "input_boolean"
        case .input_button: return "input_button"
        case .light: return "light"
        case .lock: return "lock"
        case .scene: return "scene"
        case .script: return "script"
        case .switch_button: return "switch"
        case .unsupported: return "unsupported"
        }
    }
    
    var localizedDescription: String {
        switch self {
        case .button: return L10n.Carplay.Labels.buttons
        case .cover: return L10n.Carplay.Labels.covers
        case .input_boolean: return L10n.Carplay.Labels.inputBooleans
        case .input_button: return L10n.Carplay.Labels.inputButtons
        case .light: return L10n.Carplay.Labels.lights
        case .lock: return L10n.Carplay.Labels.locks
        case .scene: return L10n.Carplay.Labels.scenes
        case .script: return L10n.Carplay.Labels.scripts
        case .switch_button: return L10n.Carplay.Labels.switches
        case .unsupported: return ""
        }
    }
    
    var isSupported: Bool {
        return self != .unsupported
    }
    
    init(domain: String) {
        self = Self.allCases.first(where: { $0.domain == domain }) ?? .unsupported
    }
}
