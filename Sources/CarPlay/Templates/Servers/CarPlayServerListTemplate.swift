import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayServersListTemplate: CarPlayTemplateProvider {
    static let carPlayPreferredServerKey = "carPlay-server"

    private let viewModel: CarPlayServerListViewModel

    var template: CPListTemplate
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

    @objc func update() {
        var serverList: [CPListItem] = []
        for serverOption in Current.servers.all {
            let serverItem = CPListItem(
                text: serverOption.info.name,
                detailText: nil
            )
            serverItem.handler = { [weak self] _, completion in
                self?.viewModel.setServer(server: serverOption)
                completion()
            }
            serverItem.accessoryType = viewModel.preferredServerId == serverOption.identifier.rawValue ? .cloud : .none
            serverList.append(serverItem)
        }
        let section = CPListSection(items: serverList, header: L10n.CarPlay.Labels.selectServer, sectionIndexTitle: nil)
        let advancedSection = CPListSection(items: [
            {
                let item = CPListItem(
                    text: L10n.CarPlay.Labels.Settings.Advanced.Section.Button.title,
                    detailText: L10n.CarPlay.Labels.Settings.Advanced.Section.Button.detail
                )
                item.handler = { _, _ in
                    fatalError("Intentional crash, triggered from CarPlay advanced option to restart App.")
                }
                return item
            }(),
        ], header: L10n.CarPlay.Labels.Settings.Advanced.Section.title, sectionIndexTitle: nil)
        template.updateSections([section, advancedSection])
    }

    func showNoServerAlert() {
        guard interfaceController?.presentedTemplate == nil else {
            return
        }

        let alertTemplate = CarPlayNoServerAlert()
        alertTemplate.interfaceController = interfaceController
        alertTemplate.present()
    }
}
