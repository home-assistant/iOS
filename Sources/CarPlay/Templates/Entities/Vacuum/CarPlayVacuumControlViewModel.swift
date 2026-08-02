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
