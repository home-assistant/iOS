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
    private var entitiesGridTemplate: EntitiesListTemplate?
    private var domainsListTemplate: DomainsListTemplate?

    private let carPlayPreferredServerKey = "carPlay-server"

    private var serverId: Identifier<Server>?

    private func setServer(server: Server) {
        serverId = server.identifier
        prefs.set(server.identifier.rawValue, forKey: carPlayPreferredServerKey)
        setDomainListTemplate(for: server)
        updateServerListButton()
    }

    private func updateServerListButton() {
        domainsListTemplate?.setServerListButton(show: Current.servers.all.count > 1)
    }

    @objc private func updateServerList() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.updateServerListButton()
            if self.serverId == nil {
                /// No server is selected
                guard let server = self.getServer() else {
                    Current.Log.info("No server connected")
                    return
                }
                self.setServer(server: server)
            }
        }
    }

    private func showNoServerAlert() {
        guard interfaceController?.presentedTemplate == nil else {
            return
        }

        let loginAlertAction = CPAlertAction(title: L10n.Carplay.Labels.alreadyAddedServer, style: .default) { _ in
            if !Current.servers.all.isEmpty {
                self.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }
        }
        let alertTemplate = CPAlertTemplate(
            titleVariants: [L10n.Carplay.Labels.noServersAvailable],
            actions: [loginAlertAction]
        )
        interfaceController?.presentTemplate(alertTemplate, animated: true, completion: nil)
    }

    private func setDomainListTemplate(for server: Server) {
        guard let interfaceController else { return }

        let entities = Current.api(for: server).connection.caches.states

        domainsListTemplate = DomainsListTemplate(
            title: server.info.name,
            entities: entities,
            serverButtonHandler: { [weak self] _ in
                self?.setServerListTemplate()
            },
            server: server
        )

        guard let domainsListTemplate else { return }

        domainsListTemplate.interfaceController = interfaceController

        interfaceController.setRootTemplate(domainsListTemplate.template, animated: true, completion: nil)
        domainsListTemplate.updateSections()
    }

    private func setServerListTemplate() {
        var serverList: [CPListItem] = []
        for server in Current.servers.all {
            let serverItem = CPListItem(
                text: server.info.name,
                detailText: "\(server.info.connection.activeURLType.description) - \(server.info.connection.activeURL().absoluteString)"
            )
            serverItem.handler = { [weak self] _, completion in
                self?.setServer(server: server)
                if let templates = self?.interfaceController?.templates, templates.count > 1 {
                    self?.interfaceController?.popTemplate(animated: true, completion: nil)
                }
                completion()
            }
            serverItem.accessoryType = serverId == server.identifier ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList)
        let serverListTemplate = CPListTemplate(title: L10n.Carplay.Labels.servers, sections: [section])
        interfaceController?.pushTemplate(serverListTemplate, animated: true, completion: nil)
    }

    private func setEmptyTemplate(interfaceController: CPInterfaceController) {
        interfaceController.setRootTemplate(CPInformationTemplate(
            title: L10n.About.Logo.title,
            layout: .leading,
            items: [],
            actions: []
        ), animated: true, completion: nil)
    }

    /// Get server for ID or first server available
    private func getServer(id: Identifier<Server>? = nil) -> Server? {
        guard let id = id else {
            return Current.servers.all.first
        }
        return  Current.servers.server(for: id)
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

        if let serverIdentifier = prefs.string(forKey: carPlayPreferredServerKey),
           let selectedServer = Current.servers.server(forServerIdentifier: serverIdentifier) {
            setServer(server: selectedServer)
        } else if let server = getServer() {
            setServer(server: server)
        } else {
           setEmptyTemplate(interfaceController: interfaceController)
        }

        updateServerList()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateServerList),
            name: HAConnectionState.didTransitionToStateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateServerList),
            name: HomeAssistantAPI.didConnectNotification,
            object: nil
        )

        /// Observer for servers list changes
        Current.servers.add(observer: self)

        if Current.servers.all.isEmpty {
            showNoServerAlert()
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        NotificationCenter.default.removeObserver(self)
        Current.servers.remove(observer: self)
    }
}

// MARK: - ServerObserver
@available(iOS 16.0, *)
extension CarPlaySceneDelegate: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {

        defer {
            updateServerListButton()
        }

        guard let server = getServer(id: serverId) else {
            serverId = nil

            if let server = getServer() {
                setServer(server: server)
            } else if interfaceController?.presentedTemplate != nil {
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            } else {
                showNoServerAlert()
            }

            return
        }
        setServer(server: server)
    }
}
