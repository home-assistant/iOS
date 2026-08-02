import Foundation
import HAKit
import PromiseKit
import Shared

final class CarPlayVacuumControlViewModel {
    let server: Server
    let entityId: String
    private(set) var entityName: String
    private(set) var entity: HAEntity
    weak var templateProvider: CarPlayVacuumControlTemplate?

    /// Areas the vacuum has segments mapped to, resolved against the local area registry. Empty
    /// until `loadCleanableAreas` answers — or when the user has mapped nothing, which the picker
    /// surfaces as an empty state.
    private(set) var cleanableAreas: [AppArea] = []
    /// Whether the mapping fetch is still in flight, so the picker can say so rather than looking
    /// like an empty mapping.
    private(set) var isLoadingAreas = false
    /// Area ids picked for the next `clean_area` call, in tap order — the service takes an ordered
    /// list, and the frontend surfaces the same numbering.
    private(set) var selectedAreaIds: [String] = []

    init(server: Server, entity: HAEntity) {
        self.server = server
        self.entityId = entity.entityId
        self.entityName = entity.attributes.friendlyName ?? entity.entityId
        self.entity = entity
    }

    var capabilities: VacuumCapabilities {
        VacuumCapabilities(entity: entity)
    }

    /// Whether the vacuum is actively cleaning, which flips the primary row to pause.
    var isCleaning: Bool {
        entity.state == "cleaning"
    }

    var stateText: String {
        Domain.vacuum.contextualStateDescription(for: entity, serverId: server.identifier.rawValue)
    }

    func updateStates(serverId: String, entities: HACachedStates) {
        guard serverId == server.identifier.rawValue, let updated = entities[entityId] else { return }
        entity = updated
        entityName = updated.attributes.friendlyName ?? updated.entityId
        templateProvider?.refreshDisplayedValues()
    }

    // MARK: - Commands

    func start() {
        send(service: .start)
    }

    func pause() {
        send(service: .pause)
    }

    func stop() {
        send(service: .stop)
    }

    func returnToBase() {
        send(service: .returnToBase)
    }

    func locate() {
        send(service: .locate)
    }

    func setFanSpeed(_ speed: String) {
        send(service: .setFanSpeed, data: ["fan_speed": speed])
    }

    // MARK: - Clean areas

    /// Fetches the vacuum's area mapping and resolves it against the local area registry. The
    /// mapping lives in the entity registry (WebSocket only) and changes rarely, so it is fetched
    /// when the picker opens rather than kept in sync.
    func loadCleanableAreas(completion: @escaping () -> Void) {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to load vacuum area mapping for \(entityId)")
            completion()
            return
        }
        isLoadingAreas = true
        connection.send(.vacuumAreaMapping(entityId: entityId)).promise
            .done { [weak self] mapping in
                guard let self else { return }
                cleanableAreas = Self.resolveAreas(ids: mapping.areaIds, serverId: server.identifier.rawValue)
            }
            .catch { error in
                Current.Log.error("Failed to load vacuum area mapping for \(self.entityId): \(error)")
            }
            .finally { [weak self] in
                self?.isLoadingAreas = false
                completion()
            }
    }

    /// Maps registry area ids to the app's stored areas, dropping any the app doesn't know about
    /// (a mapping can outlive an area deletion) and keeping the mapping's order.
    private static func resolveAreas(ids: [String], serverId: String) -> [AppArea] {
        guard !ids.isEmpty else { return [] }
        let areas: [AppArea]
        do {
            areas = try AppArea.fetchAreas(for: serverId)
        } catch {
            Current.Log.error("Failed to fetch areas for CarPlay vacuum clean areas: \(error.localizedDescription)")
            return []
        }
        let areasById = Dictionary(areas.map { ($0.areaId, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { areasById[$0] }
    }

    /// Adds or removes an area from the pending selection, preserving tap order.
    func toggleAreaSelection(_ areaId: String) {
        if let index = selectedAreaIds.firstIndex(of: areaId) {
            selectedAreaIds.remove(at: index)
        } else {
            selectedAreaIds.append(areaId)
        }
    }

    /// 1-based position of an area in the pending selection, or nil when it isn't selected.
    func selectionOrder(of areaId: String) -> Int? {
        selectedAreaIds.firstIndex(of: areaId).map { $0 + 1 }
    }

    func clearAreaSelection() {
        selectedAreaIds = []
    }

    func startCleaningSelectedAreas() {
        guard !selectedAreaIds.isEmpty else { return }
        send(service: .cleanArea, data: ["cleaning_area_id": selectedAreaIds])
        clearAreaSelection()
    }

    // MARK: - Private

    private func send(service: Service, data: [String: Any] = [:]) {
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available for CarPlay vacuum service call on \(entityId)")
            return
        }
        connection.send(.callEntityService(domain: .vacuum, service, entityId: entityId, data: data)).promise
            .done { _ in
                Current.Log.verbose("CarPlay vacuum \(service.rawValue) succeeded for \(self.entityId)")
            }
            .catch { [weak self] error in
                guard let self else { return }
                Current.Log.error("CarPlay vacuum \(service.rawValue) failed for \(entityId): \(error)")
            }
    }
}
