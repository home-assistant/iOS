import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
class CarPlayDomainsListTemplate: CarPlayTemplateProvider {
    private var childTemplateProvider: (any CarPlayTemplateProvider)?

    private let viewModel: CarPlayDomainsListViewModel

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

    func update() {
        viewModel.update()
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            viewModel.cancelSubscriptionToken()
        }
        childTemplateProvider?.templateWillDisappear(template: template)
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
        childTemplateProvider?.templateWillAppear(template: template)
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
