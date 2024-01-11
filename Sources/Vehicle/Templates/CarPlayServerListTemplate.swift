import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayServersListTemplate: CarPlayTemplateProvider {
    private var serverId: Identifier<Server>?
    private(set) static var carPlayPreferredServerKey = "carPlay-server"

    var template: CPTemplate
    weak var interfaceController: CPInterfaceController?

    init() {
        self.template = CPListTemplate(title: "", sections: [])
        self.template.tabTitle = L10n.Carplay.Labels.servers
        self.template.tabImage = MaterialDesignIcons.cogIcon.carPlayIcon(color: nil)
    }

    func templateWillDisappear(template: CPTemplate) {
        Current.servers.remove(observer: self)
    }

    func templateWillAppear(template: CPTemplate) {
        /// Observer for servers list changes
        Current.servers.add(observer: self)
        if template == self.template {
            update()
        }
    }

    @objc func update() {
        var serverList: [CPListItem] = []
        for server in Current.servers.all {
            let serverItem = CPListItem(
                text: server.info.name,
                detailText: nil
            )
            serverItem.handler = { [weak self] _, completion in
                self?.setServer(server: server)
                completion()
            }
            serverItem.accessoryType = serverId == server.identifier ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList, header: L10n.Carplay.Labels.selectServer, sectionIndexTitle: nil)
        (template as? CPListTemplate)?.updateSections([section]) 
    }

    private func setServer(server: Server) {
        serverId = server.identifier
        prefs.set(server.identifier.rawValue, forKey: CarPlayServersListTemplate.carPlayPreferredServerKey)
        update()
    }

    private func showNoServerAlert() {
        guard interfaceController?.presentedTemplate == nil else {
            return
        }

        let alertTemplate = CarPlayNoServerAlert()
        alertTemplate.interfaceController = interfaceController
        alertTemplate.present()
    }
}

@available(iOS 16.0, *)
extension CarPlayServersListTemplate: ServerObserver {
    func serversDidChange(_ serverManager: ServerManager) {
        guard let serverId, let server = serverManager.server(for: serverId, fallback: true) else {
            if interfaceController?.presentedTemplate != nil {
                interfaceController?.dismissTemplate(animated: true, completion: nil)
            } else {
                showNoServerAlert()
            }
            return
        }
        setServer(server: server)
    }
}
