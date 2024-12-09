import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayServersListTemplate: CarPlayTemplateProvider {
    static let carPlayPreferredServerKey = "carPlay-server"

    private let viewModel: CarPlayServerListViewModel

    var template: CPListTemplate
    weak var sceneDelegate: CarPlaySceneDelegate?
    weak var interfaceController: CPInterfaceController? {
        didSet {
            viewModel.interfaceController = interfaceController
        }
    }

    init(viewModel: CarPlayServerListViewModel) {
        self.viewModel = viewModel
        self.template = CPListTemplate(title: "", sections: [])
        template.tabTitle = L10n.CarPlay.Labels.Tab.settings
        template.tabImage = MaterialDesignIcons.cogIcon.carPlayIcon()

        viewModel.templateProvider = self
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            viewModel.removeServerObserver()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            viewModel.addServerObserver()
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        /* no-op */
    }

    @objc func update() {
        let serverList: [CPListItem] = Current.servers.all.filter({
            // Only display servers that can be used in the user current environment
            $0.info.connection.activeURL() != nil
        }).compactMap { server in
            serverItem(server: server)
        }
        let serversSection = CPListSection(
            items: serverList,
            header: L10n.CarPlay.Labels.selectServer,
            sectionIndexTitle: nil
        )

        let advancedSection = CPListSection(
            items: [restartItem],
            header: L10n.CarPlay.Labels.Settings.Advanced.Section.title,
            sectionIndexTitle: nil
        )

        template.updateSections([
            serversSection,
            advancedSection,
        ])
    }

    func showNoServerAlert() {
        guard interfaceController?.presentedTemplate == nil else {
            return
        }

        let alertTemplate = CarPlayNoServerAlert()
        alertTemplate.interfaceController = interfaceController
        alertTemplate.present()
    }

    private func serverItem(server: Server) -> CPListItem {
        let serverItem = CPListItem(
            text: server.info.name,
            detailText: nil
        )
        serverItem.handler = { [weak self] _, completion in
            self?.viewModel.setServer(server: server)
            completion()
        }
        serverItem.accessoryType = viewModel.preferredServerId == server.identifier.rawValue ? .cloud : .none
        return serverItem
    }

    private var restartItem: CPListItem {
        let item = CPListItem(
            text: L10n.CarPlay.Labels.Settings.Advanced.Section.Button.title,
            detailText: L10n.CarPlay.Labels.Settings.Advanced.Section.Button.detail
        )
        item.handler = { _, _ in
            fatalError("Intentional crash, triggered from CarPlay advanced option to restart App.")
        }
        return item
    }
}
