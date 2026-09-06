import AppIntents
import Foundation
import Shared

/// Runs the on, off and toggle commands, resolving the service from the entity's domain so a cover
/// opens where a light turns on. Mirrors the frontend's toggle model in `Domain+Toggle`.
enum ControlEntityIntentRunner {
    enum Action {
        case turnOn
        case turnOff
        case toggle
    }

    /// Performs `action` and returns the sentence Siri should speak.
    @available(macOS 13.0, watchOS 9.4, *)
    static func perform(_ action: Action, on entity: ControllableEntityAppEntity) async throws -> String {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: entity.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        guard let domain = entity.domain, let services = domain.toggleServices else {
            throw ShortcutAppIntentError(L10n.AppIntents.Control.Error.unsupported(entity.displayString))
        }

        let service = try await service(for: action, domain: domain, entity: entity, server: server, services: services)
        try await AppIntentServerAPI.callAction(
            server: server,
            domain: domain.serviceDomain,
            service: service.rawValue,
            data: ["entity_id": entity.entityId],
            returnResponse: false
        )
        return dialog(for: service, entityName: entity.displayString)
    }

    @available(macOS 13.0, watchOS 9.4, *)
    private static func service(
        for action: Action,
        domain: Domain,
        entity: ControllableEntityAppEntity,
        server: Server,
        services: (on: Service, off: Service)
    ) async throws -> Service {
        // A scene's off service is its on service, so anything but "turn on" would activate it.
        if action != .turnOn, !domain.isVoiceSwitchable {
            throw ShortcutAppIntentError(L10n.AppIntents.Control.Error.onlyTurnsOn(entity.displayString))
        }

        switch action {
        case .turnOn:
            return services.on
        case .turnOff:
            return services.off
        case .toggle:
            // A toggle needs to know which way to go, and the state is the only thing that says so.
            let state = try await AppIntentServerAPI.entityState(server: server, entityId: entity.entityId).state
            return domain.toggleService(state: state) ?? services.off
        }
    }

    /// The spoken confirmation, worded for what the service actually did.
    static func dialog(for service: Service, entityName: String) -> String {
        switch service {
        case .openCover, .openValve, .unlock:
            L10n.AppIntents.Dialog.opened(entityName)
        case .closeCover, .closeValve, .lock:
            L10n.AppIntents.Dialog.closed(entityName)
        case .turnOff:
            L10n.AppIntents.Dialog.turnedOff(entityName)
        case .toggle:
            L10n.AppIntents.Dialog.toggled(entityName)
        default:
            L10n.AppIntents.Dialog.turnedOn(entityName)
        }
    }
}
