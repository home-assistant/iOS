import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayServersListTemplate: CarPlayTemplateProvider {
    private(set) static var carPlayPreferredServerKey = "carPlay-server"

    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private var preferredServerId: String {
        prefs.string(forKey: CarPlayServersListTemplate.carPlayPreferredServerKey) ?? ""
    }

    init() {
        self.template = CPListTemplate(title: "", sections: [])
        template.tabTitle = L10n.Carplay.Labels.servers
        template.tabImage = MaterialDesignIcons.cogIcon.carPlayIcon(color: nil)
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
        for serverOption in Current.servers.all {
            let serverItem = CPListItem(
                text: serverOption.info.name,
                detailText: nil
            )
            serverItem.handler = { [weak self] _, completion in
                self?.setServer(server: serverOption)
                completion()
            }
            serverItem.accessoryType = preferredServerId == serverOption.identifier.rawValue ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList, header: L10n.Carplay.Labels.selectServer, sectionIndexTitle: nil)
        template.updateSections([section])
    }

    private func setServer(server: Server) {
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
        guard let server = serverManager.serverOrFirstIfAvailable(for: Identifier<Server>(rawValue: preferredServerId)) else {
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
