import CarPlay
import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListTemplate: CarPlayTemplateProvider {
    enum CPEntityError: Error {
        case unknown
    }

    private let domain: String
    private var server: Server
    private let entitiesCachedStates: HACache<HACachedStates>
    private var currentPage: Int = 0

    private var itemsPerPage: Int = CPListTemplate.maximumItemCount
    private var entitiesSubscriptionToken: HACancellable?

    var template: CPListTemplate
    weak var interfaceController: CPInterfaceController?

    private let entityIconSize: CGSize = .init(width: 64, height: 64)
    private let entityIdKey = "entityId"

    private let paginatedListTemplate: CarPlayPaginatedListTemplate
    private var entitiesIdsCurrentlyInList: [String] = []

    init(title: String, domain: String, server: Server, entitiesCachedStates: HACache<HACachedStates>) {
        self.domain = domain
        self.server = server
        self.entitiesCachedStates = entitiesCachedStates
        self.paginatedListTemplate = CarPlayPaginatedListTemplate(title: title, items: [])
        self.template = paginatedListTemplate.template
    }

    func templateWillDisappear(template: CPTemplate) {
        if self.template == template {
            entitiesSubscriptionToken?.cancel()
        }
    }

    func templateWillAppear(template: CPTemplate) {
        if self.template == template {
            update()
            entitiesSubscriptionToken = entitiesCachedStates.subscribe { [weak self] _, _ in
                self?.update()
            }
        }
    }

    func update() {
        guard let entities = entitiesCachedStates.value else { return }

        let entitiesFiltered = entities.all.filter { $0.domain == domain }
        let entitiesSorted = entitiesFiltered
            .sorted(by: { $0.attributes.friendlyName ?? $0.entityId < $1.attributes.friendlyName ?? $1.entityId })

        // Prevent unecessary update and UI glitch for non-touch screen CarPlay
        let entitiesIds = entitiesSorted.map(\.entityId).sorted()
        guard entitiesIdsCurrentlyInList != entitiesIds else {
            updateItemsState(entities: entitiesSorted)
            return
        }
        entitiesIdsCurrentlyInList = entitiesIds

        var items: [CPListItem] = []

        entitiesSorted.forEach { entity in
            let item = CPListItem(
                text: entity.attributes.friendlyName ?? entity.entityId,
                detailText: entity.localizedState,
                image: entity.getIcon() ?? MaterialDesignIcons.bookmarkIcon.image(ofSize: entityIconSize, color: nil)
            )

            item.userInfo = [entityIdKey: entity.entityId]
            item.handler = { _, completion in
                firstly { [weak self] () -> Promise<Void> in
                    guard let self = self else { return .init(error: CPEntityError.unknown) }

                    let api = Current.api(for: self.server)

                    if let domain = Domain(rawValue: entity.domain), domain == .lock {
                        self.displayLockConfirmation(entity: entity, completion: {
                            entity.onPress(for: api).catch { error in
                                Current.Log.error("Received error from callService during onPress call: \(error)")
                            }
                        })
                        return .value
                    } else {
                        return entity.onPress(for: api)
                    }
                }.done {
                    completion()
                }.catch { error in
                    Current.Log.error("Received error from callService during onPress call: \(error)")
                    completion()
                }
            }

            items.append(item)
        }

        paginatedListTemplate.updateItems(items: items, refreshUI: true)
    }

    private func updateItemsState(entities: [HAEntity]) {
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

    private func displayLockConfirmation(entity: HAEntity, completion: @escaping () -> Void) {
        guard let state = Domain.State(rawValue: entity.state) else { return }
        var title = ""
        switch state {
        case .locked, .locking:
            title = L10n.Carplay.Unlock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
        default:
            title = L10n.Carplay.Lock.Confirmation.title(entity.attributes.friendlyName ?? entity.entityId)
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