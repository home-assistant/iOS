import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayEntitiesListViewModel
    private let condensedEntitiesPerRow = 3
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?
    private let paginatedListTemplate: CarPlayPaginatedListTemplate

    init(
        viewModel: CarPlayEntitiesListViewModel,
        title: String
    ) {
        self.paginatedListTemplate = CarPlayPaginatedListTemplate(title: title, items: [])
        guard let template = paginatedListTemplate.listTemplate else {
            fatalError("Expected CarPlayPaginatedListTemplate to create a CPListTemplate")
        }
        self.template = template
        self.viewModel = viewModel

        viewModel.templateProvider = self
        template.emptyViewSubtitleVariants = [L10n.CarPlay.State.Loading.title]
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
        if #available(iOS 26.0, *) {
            paginatedListTemplate.updateItems(items: condensedItems(entityProviders: entityProviders))
        } else {
            paginatedListTemplate.updateItems(items: listItems(entityProviders: entityProviders))
        }
    }

    func displayLockConfirmation(entity: HAEntity, completion: @escaping () -> Void) {
        CarPlayLockConfirmation.show(
            entityName: entity.attributes.friendlyName ?? entity.entityId,
            currentState: entity.state,
            interfaceController: interfaceController,
            completion: completion
        )
    }

    private func listItems(entityProviders: [CarPlayEntityListItem]) -> [CPListItem] {
        entityProviders.map { entityProvider in
            entityProvider.template.handler = { [weak self] _, completion in
                self?.viewModel.handleEntityTap(entity: entityProvider.entity, completion: completion)
            }
            return entityProvider.template
        }
    }

    @available(iOS 26.0, *)
    private func condensedItems(entityProviders: [CarPlayEntityListItem]) -> [any CPListTemplateItem] {
        stride(from: 0, to: entityProviders.count, by: condensedEntitiesPerRow).map { startIndex in
            let rowProviders = Array(entityProviders[startIndex ..< min(
                startIndex + condensedEntitiesPerRow,
                entityProviders.count
            )])
            let item = CPListImageRowItem(
                text: nil,
                condensedElements: rowProviders.map { $0.condensedElement() },
                allowsMultipleLines: true
            )
            item.listImageRowHandler = { [weak self] _, index, completion in
                guard rowProviders.indices.contains(index) else {
                    completion()
                    return
                }
                self?.viewModel.handleEntityTap(entity: rowProviders[index].entity, completion: completion)
            }
            return item
        }
    }
}
