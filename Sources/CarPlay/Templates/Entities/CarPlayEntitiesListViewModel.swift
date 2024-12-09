import Foundation
import HAKit
import PromiseKit
import Shared

@available(iOS 16.0, *)
final class CarPlayEntitiesListViewModel {
    enum FilterType {
        case domain(String)
        case areaId(entityIds: [String])
    }

    enum CPEntityError: Error {
        case unknown
    }

    private let filterType: FilterType
    private var server: Server
    private var entitiesCachedStates: HACachedStates

    private var entityProviders: [CarPlayEntityListItem] = []
    weak var templateProvider: CarPlayEntitiesListTemplate?

    private var sortedEntities: [HAEntity] {
        let entities = entitiesCachedStates.all.filter({ entity in
            switch self.filterType {
            case let .domain(domain):
                return entity.domain == domain
            case let .areaId(entityIdsAllowed):
                if let domain = Domain(rawValue: entity.domain) {
                    return entityIdsAllowed.contains(entity.entityId) && domain.isCarPlaySupported
                } else {
                    return false
                }
            }
        })

        let entitiesSorted = entities.sorted(by: { e1, e2 in
            let lowPriorityStates: Set<String> = [Domain.State.unknown.rawValue, Domain.State.unavailable.rawValue]
            let state1 = e1.state
            let state2 = e2.state

            let deviceClassOrder: [HAEntity.DeviceClass] = [.garage, .gate]

            if lowPriorityStates.contains(state1), !lowPriorityStates.contains(state2) {
                return false
            } else if lowPriorityStates.contains(state2), !lowPriorityStates.contains(state1) {
                return true
            } else {
                if deviceClassOrder.contains(e1.deviceClass), !deviceClassOrder.contains(e2.deviceClass) {
                    return true
                } else if deviceClassOrder.contains(e2.deviceClass), !deviceClassOrder.contains(e1.deviceClass) {
                    return false
                }
            }

            return (e1.attributes.friendlyName ?? e1.entityId) < (e2.attributes.friendlyName ?? e2.entityId)
        })

        return entitiesSorted
    }

    init(
        filterType: FilterType,
        server: Server,
        entitiesCachedStates: HACachedStates
    ) {
        self.filterType = filterType
        self.server = server
        self.entitiesCachedStates = entitiesCachedStates
    }

    func update() {
        entityProviders = sortedEntities.map { entity in
            CarPlayEntityListItem(serverId: server.identifier.rawValue, entity: entity)
        }

        templateProvider?.updateItems(entityProviders: entityProviders)
    }

    func updateStates(entities: HACachedStates) {
        entitiesCachedStates = entities
        // Avoid computing property several times
        let sortedEntities = sortedEntities
        entityProviders.forEach { item in
            guard let updatedEntity = sortedEntities.first(where: { $0.entityId == item.entity.entityId }),
                  item.entity.state != updatedEntity.state else { return }
            item.update(serverId: server.identifier.rawValue, entity: updatedEntity)
        }
    }

    func handleEntityTap(entity: HAEntity, completion: @escaping () -> Void) {
        firstly { [weak self] () -> Promise<Void> in
            guard let self else { return .init(error: CPEntityError.unknown) }

            guard let api = Current.api(for: server) else {
                Current.Log.error("No API available to handle CarPlay entity tap")
                return .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
            }

            if let domain = Domain(rawValue: entity.domain), domain == .lock {
                templateProvider?.displayLockConfirmation(entity: entity, completion: {
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
}
