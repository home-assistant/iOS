import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayEntitiesListViewModel
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?
    private let entityIdKey = "entityId"
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
        guard let state = Domain.State(rawValue: entity.state) else { return }
        var title = ""
        switch state {
        case .locked, .locking:
            title = L10n.CarPlay.Unlock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
        default:
            title = L10n.CarPlay.Lock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
        }

        let alert = CPAlertTemplate(titleVariants: [title], actions: [
            .init(title: L10n.Alerts.Confirm.cancel, style: .cancel, handler: { [weak self] _ in
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
            .init(title: L10n.Alerts.Confirm.confirm, style: .destructive, handler: { [weak self] _ in
                completion()
                self?.interfaceController?.dismissTemplate(animated: true, completion: nil)
            }),
        ])

        interfaceController?.presentTemplate(alert, animated: true, completion: nil)
    }
}
