import CarPlay
import Foundation
import HAKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListTemplate: CarPlayTemplateProvider {
    private let viewModel: CarPlayEntitiesListViewModel
    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private let entityIconSize: CGSize = .init(width: 64, height: 64)
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
        paginatedListTemplate.template.emptyViewSubtitleVariants = [L10n.CarPlay.NoEntities.title]
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            viewModel.cancelSubscriptionToken()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if self.template == template {
            update()
            viewModel.subscribe()
        }
    }

    func update() {
        viewModel.update()
    }

    func updateItems(entitiesSorted: [HAEntity]) {
        var items: [CPListItem] = []

        entitiesSorted.forEach { entity in
            let item = CPListItem(
                text: entity.attributes.friendlyName ?? entity.entityId,
                detailText: entity.localizedState,
                image: entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.image(ofSize: entityIconSize, color: nil)
            )

            item.userInfo = [entityIdKey: entity.entityId]
            item.handler = { [weak self] _, completion in
                self?.viewModel.handleEntityTap(entity: entity, completion: completion)
            }

            items.append(item)
        }

        paginatedListTemplate.updateItems(items: items, refreshUI: true)
    }

    func updateItemsState(entities: [HAEntity]) {
        guard let visibleItems = paginatedListTemplate.template.sections.first?.items as? [CPListItem] else { return }
        visibleItems.forEach { listItem in
            guard let userInfo = listItem.userInfo as? [String: String],
                  let entity = entities.first(where: { $0.entityId == userInfo[entityIdKey] }) else { return }
            listItem.setDetailText(entity.localizedState)
            listItem
                .setImage(
                    entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon
                        .image(ofSize: entityIconSize, color: nil)
                )
        }
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
