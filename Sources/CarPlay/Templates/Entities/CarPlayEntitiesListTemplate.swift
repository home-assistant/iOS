import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayEntitiesListViewModel
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?
    private let paginatedListTemplate: CarPlayPaginatedListTemplate

    init(
        viewModel: CarPlayEntitiesListViewModel,
        title: String
    ) {
        self.paginatedListTemplate = CarPlayPaginatedListTemplate(title: title, items: [])
        self.template = paginatedListTemplate.template
        self.viewModel = viewModel

        viewModel.templateProvider = self
        paginatedListTemplate.template.emptyViewSubtitleVariants = [L10n.CarPlay.State.Loading.title]
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            /* no-op */
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if self.template == template {
            update()
        }
    }

    func entitiesStateChange(serverId: String, entities: HACachedStates) {
        viewModel.updateStates(entities: entities)
    }

    func update() {
        viewModel.update()
    }

    func updateItems(entityProviders: [CarPlayEntityListItem]) {
        for entityProvider in entityProviders {
            entityProvider.template.handler = { [weak self] _, completion in
                self?.viewModel.handleEntityTap(entity: entityProvider.entity, completion: completion)
            }
        }

        paginatedListTemplate.updateItems(items: entityProviders.map(\.template))
    }

    func displayLockConfirmation(entity: HAEntity, completion: @escaping () -> Void) {
        CarPlayLockConfirmation.show(
            entityName: entity.attributes.friendlyName ?? entity.entityId,
            currentState: entity.state,
            interfaceController: interfaceController,
            completion: completion
        )
    }
}
