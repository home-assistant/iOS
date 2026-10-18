import Foundation

/// The frontend's toggle model, ported so a widget tile behaves the way a tile card does.
///
/// Each member names the home-assistant/frontend source it mirrors, all under `src/`:
/// - `common/const.ts`: `STATES_OFF`
/// - `common/entity/get_toggle_action.ts`: the on and off service each domain toggles between
/// - `common/entity/can_toggle_domain.ts`: a domain toggles when it has both of those services
/// - `panels/lovelace/common/entity/toggle-entity.ts` and `turn-on-off-entity.ts`: the call a
///   toggle makes
public extension Domain {
    /// `STATES_OFF`: a toggle turns an entity in one of these states on, and one in any other
    /// state off.
    static let statesOff: [String] = ["closed", "locked", "off"]

    /// `getToggleAction`, narrowed by `canToggleDomain`: the service a toggle calls to turn an
    /// entity of this domain on, and the one to turn it off. A button or a scene has only the one,
    /// which the frontend uses for both. `nil` for a domain Home Assistant registers no such pair
    /// for, which is what leaves "toggle" out of the frontend's action list. Whether one entity
    /// supports the pair is `canToggle(supportedFeatures:)`.
    var toggleServices: (on: Service, off: Service)? {
        switch self {
        case .button, .inputButton:
            return (.press, .press)
        case .scene:
            return (.turnOn, .turnOn)
        case .cover:
            return (.openCover, .closeCover)
        case .valve:
            return (.openValve, .closeValve)
        case .lock:
            return (.unlock, .lock)
        case .automation, .camera, .climate, .fan, .group, .humidifier, .inputBoolean, .light, .mediaPlayer,
             .remote, .script, .siren, .switch, .waterHeater:
            return (.turnOn, .turnOff)
        default:
            return nil
        }
    }

    /// `canToggleDomain`: whether a toggle can do anything for this domain.
    var canToggle: Bool {
        toggleServices != nil
    }

    /// The `supported_features` bits an entity of this domain must carry for its on/off pair to
    /// work — `getToggleAction`'s feature requirement: a camera's on/off, a climate's, media
    /// player's, or siren's turn on and off, a cover's open and close. `nil` for a domain whose
    /// services always exist.
    var toggleRequiredFeatures: Int? {
        switch self {
        case .camera:
            // CameraEntityFeature.ON_OFF
            return 1 << 0
        case .climate:
            return ClimateEntityFeature.turnOn.rawValue | ClimateEntityFeature.turnOff.rawValue
        case .cover:
            return CoverCapabilities.Feature.open.rawValue | CoverCapabilities.Feature.close.rawValue
        case .mediaPlayer:
            // MediaPlayerEntityFeature.TURN_ON | TURN_OFF
            return 1 << 7 | 1 << 8
        case .siren:
            // SirenEntityFeature.TURN_ON | TURN_OFF
            return 1 << 0 | 1 << 1
        default:
            return nil
        }
    }

    /// `canToggleState`: whether an entity of this domain with these `supported_features` can be
    /// toggled. With no features to go on — the state hasn't been read — this is `canToggle`,
    /// the way the frontend falls back to `canToggleDomain` without a state object.
    func canToggle(supportedFeatures: Int?) -> Bool {
        guard canToggle else { return false }
        guard let required = toggleRequiredFeatures, let supportedFeatures else { return true }
        return supportedFeatures & required == required
    }

    /// Whether a toggle has to read the entity's state to know which service to call. A button
    /// or a scene has the same service either way, so there is nothing to look up.
    var toggleIsStateAware: Bool {
        guard let services = toggleServices else { return false }
        return services.on != services.off
    }

    /// `turnOnOffEntity`: the domain any service call for this entity is addressed to. A group
    /// has no services of its own (the integration registers only `reload`, `set` and
    /// `remove`), so it is controlled through `homeassistant.turn_on`, `turn_off` and `toggle`.
    var serviceDomain: String {
        self == .group ? "homeassistant" : rawValue
    }

    /// `toggleEntity`: the service a toggle calls for an entity currently in `state`.
    func toggleService(state: String) -> Service? {
        guard let services = toggleServices else { return nil }
        return Self.statesOff.contains(state) ? services.on : services.off
    }
}
