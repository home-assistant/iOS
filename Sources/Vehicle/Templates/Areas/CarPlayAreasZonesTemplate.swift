import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayAreasZonesTemplate: CarPlayTemplateProvider {
    private var childTemplateProvider: (any CarPlayTemplateProvider)?
    private let viewModel: CarPlayAreasViewModel

    let paginatedList = CarPlayPaginatedListTemplate(
        title: L10n.CarPlay.Navigation.Tab.areas,
        items: [],
        paginationStyle: .inline
    )
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    init(viewModel: CarPlayAreasViewModel) {
        self.viewModel = viewModel
        self.template = paginatedList.template
        template.tabImage = MaterialDesignIcons.sofaIcon.carPlayIcon()
        template.tabTitle = L10n.CarPlay.Navigation.Tab.areas

        viewModel.templateProvider = self
    }

    func templateWillDisappear(template: CPTemplate) {
        if template == self.template {
            viewModel.cancelRequest()
        }
        childTemplateProvider?.templateWillDisappear(template: template)
    }

    func templateWillAppear(template: CPTemplate) {
        if template == self.template {
            update()
        }
        childTemplateProvider?.templateWillAppear(template: template)
    }

    func update() {
        viewModel.update()
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
