import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
class CarPlayDomainsListTemplate: CarPlayTemplateProvider {
    private var childTemplateProvider: (any CarPlayTemplateProvider)?

    private let viewModel: CarPlayDomainsListViewModel
    private let overrideCoverIcon = MaterialDesignIcons.garageLockIcon

    weak var interfaceController: CPInterfaceController?
    var template: CPListTemplate

    init(viewModel: CarPlayDomainsListViewModel) {
        self.viewModel = viewModel
        let listTemplate = CPListTemplate(title: L10n.About.Logo.title, sections: [])
        listTemplate.emptyViewSubtitleVariants = [L10n.CarPlay.Labels.emptyDomainList]
        self.template = listTemplate
        template.tabTitle = L10n.CarPlay.Navigation.Tab.domains
        template.tabImage = MaterialDesignIcons.devicesIcon.carPlayIcon()

        viewModel.templateProvider = self
    }

    func updateList(domains: [Domain]) {
        let items: [CPListItem] = domains.map { domain in
            let itemTitle = domain.localizedDescription
            let listItem = CPListItem(
                text: itemTitle,
                detailText: nil,
                image: domain == .cover ? overrideCoverIcon
                    .carPlayIcon() : domain.icon
                    .carPlayIcon()
            )
            listItem.accessoryType = .disclosureIndicator
            listItem.handler = { [weak self] _, completion in
                self?.viewModel.listItemHandler(domain: domain.rawValue)
                completion()
            }

            return listItem
        }

        template.updateSections([CPListSection(items: items)])
    }

    func update() {
        /* no-op */
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            /* no-op */
        }
        childTemplateProvider?.templateWillDisappear(template: template)
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            /* no-op */
        }
        childTemplateProvider?.templateWillAppear(template: template)
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        viewModel.update(entities: entities)
        viewModel.entitiesListTemplate?.entitiesStateChange(serverId: serverId, entities: entities)
    }

    func presentEntitiesList(template: CarPlayEntitiesListTemplate) {
        template.interfaceController = interfaceController

        childTemplateProvider = template
        interfaceController?.pushTemplate(
            template.template,
            animated: true,
            completion: nil
        )
    }
}
