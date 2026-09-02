import Foundation
import HAKit
import HAKit_PromiseKit
import PromiseKit

/// Toggles an entity the way the frontend's `toggleEntity` does: reads its state, then calls the
/// domain's "on" service when that state is one of `STATES_OFF` and its "off" service otherwise —
/// so a locked lock unlocks, a running script stops, and a group goes through `homeassistant`.
/// A button or a scene has a single service either way, so those skip the lookup.
public enum EntityToggler {
    public enum ToggleError: LocalizedError {
        /// The domain has no on/off service pair, so there is nothing to toggle between.
        case domainNotToggleable(Domain)
        /// The state came back without a value to decide on.
        case stateUnavailable(String)

        public var errorDescription: String? {
            switch self {
            case let .domainNotToggleable(domain):
                return "\(domain.rawValue) cannot be toggled"
            case let .stateUnavailable(entityId):
                return "No state available for \(entityId)"
            }
        }
    }

    public static func toggle(domain: Domain, entityId: String, connection: HAConnection) -> Promise<Void> {
        guard let services = domain.toggleServices else {
            return Promise(error: ToggleError.domainNotToggleable(domain))
        }

        let service: Promise<Service>
        if domain.toggleIsStateAware {
            service = currentState(of: entityId, connection: connection).map { state in
                domain.toggleService(state: state) ?? services.off
            }
        } else {
            service = .value(services.on)
        }

        return service.then { service -> Promise<Void> in
            Current.Log.verbose("Toggling \(entityId): \(domain.toggleServiceDomain).\(service.rawValue)")
            let request = HATypedRequest<HAResponseVoid>(request: .init(
                type: "call_service",
                data: [
                    "domain": domain.toggleServiceDomain,
                    "service": service.rawValue,
                    "service_data": [
                        "entity_id": entityId,
                    ],
                ]
            ))
            return connection.send(request).promise.asVoid()
        }
    }

    /// `GET /api/states/{entity_id}`, reduced to the state string a toggle decides on.
    private static func currentState(of entityId: String, connection: HAConnection) -> Promise<String> {
        Promise { seal in
            connection.send(.init(type: .rest(.get, "states/\(entityId)"))) { result in
                switch result {
                case let .success(data):
                    if let state: String = data.decode("state", fallback: nil) {
                        seal.fulfill(state)
                    } else {
                        seal.reject(ToggleError.stateUnavailable(entityId))
                    }
                case let .failure(error):
                    seal.reject(error)
                }
            }
        }
    }
}
