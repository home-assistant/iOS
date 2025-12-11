import Foundation
import GRDB
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
        // Fetch entity registry data to exclude configuration/diagnostic entities
        let entitiesWithCategories: Set<String> = {
            do {
                let registryEntities = try Current.database().read { db in
                    try AppEntityRegistryListForDisplay
                        .filter(
                            Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == server
                                .identifier.rawValue
                        )
                        .fetchAll(db)
                }
                // Create a set of entity IDs that have a non-nil category (config/diagnostic entities)
                return Set(registryEntities.filter { $0.registry.entityCategory != nil }.map(\.entityId))
            } catch {
                Current.Log
                    .error("Failed to fetch entity registry for CarPlay filtering: \(error.localizedDescription)")
                return []
            }
        }()

        let entities = entitiesCachedStates.all.filter({ entity in
            // Filter out entities with categories (configuration/diagnostic)
            guard !entitiesWithCategories.contains(entity.entityId) else {
                return false
            }

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

            let deviceClassOrder: [DeviceClass] = [.garage, .gate]

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
        // Fetch all areas for this server once and create a lookup map
        let areas: [AppArea]
        do {
            areas = try AppArea.fetchAreas(for: server.identifier.rawValue)
        } catch {
            Current.Log.error("Failed to fetch areas for CarPlay entities: \(error.localizedDescription)")
            areas = []
        }
        var entityToAreaMap: [String: String] = [:]
        for area in areas {
            for entityId in area.entities {
                entityToAreaMap[entityId] = area.name
            }
        }

        entityProviders = sortedEntities.map { entity in
            let area = entityToAreaMap[entity.entityId]
            return CarPlayEntityListItem(serverId: server.identifier.rawValue, entity: entity, area: area)
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
        guard let api = Current.api(for: server) else {
            Current.Log.error("No API available to handle CarPlay entity tap")
            completion()
            return
        }

        if let domain = Domain(rawValue: entity.domain), domain == .lock {
            // Show confirmation and use shared execution method
            templateProvider?.displayLockConfirmation(entity: entity, completion: {
                CarPlayLockConfirmation.execute(
                    entityId: entity.entityId,
                    currentState: entity.state,
                    api: api
                ) { success in
                    if !success {
                        Current.Log.error("Failed to execute lock action for entity: \(entity.entityId)")
                    }
                }
            })
            completion()
        } else {
            // For non-lock entities, use entity.onPress directly
            firstly {
                entity.onPress(for: api)
            }.done {
                completion()
            }.catch { error in
                Current.Log.error("Received error from callService during onPress call: \(error)")
                completion()
            }
        }
    }
}
