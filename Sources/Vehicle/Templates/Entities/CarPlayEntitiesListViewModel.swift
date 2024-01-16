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
    private let entitiesCachedStates: HACache<HACachedStates>

    private var entitiesSubscriptionToken: HACancellable?
    private var entitiesIdsCurrentlyInList: [String] = []
    weak var templateProvider: CarPlayEntitiesListTemplate?

    init(filterType: FilterType, server: Server, entitiesCachedStates: HACache<HACachedStates>) {
        self.filterType = filterType
        self.server = server
        self.entitiesCachedStates = entitiesCachedStates
    }

    func cancelSubscriptionToken() {
        entitiesSubscriptionToken?.cancel()
    }

    func subscribe() {
        entitiesSubscriptionToken = entitiesCachedStates.subscribe { [weak self] _, _ in
            self?.update()
        }
    }

    func update() {
        guard let entities = entitiesCachedStates.map({ cachedState in
            cachedState.all.filter { [self] entity in
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
            }
        }).value else { return }

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

        // Prevent unecessary update and UI glitch for non-touch screen CarPlay
        let entitiesIds = entitiesSorted.map(\.entityId).sorted()
        guard entitiesIdsCurrentlyInList != entitiesIds else {
            templateProvider?.updateItemsState(entities: entitiesSorted)
            return
        }
        entitiesIdsCurrentlyInList = entitiesIds

        templateProvider?.updateItems(entitiesSorted: entitiesSorted)
    }

    func handleEntityTap(entity: HAEntity, completion: @escaping () -> Void) {
        firstly { [weak self] () -> Promise<Void> in
            guard let self = self else { return .init(error: CPEntityError.unknown) }

            let api = Current.api(for: self.server)

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
