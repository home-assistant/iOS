import Foundation

/// Port of `common/entity/state_active.ts` in home-assistant/frontend: whether an entity's state
/// counts as "active", which is what decides between the accent and the muted icon color.
///
/// Kept string-based, like the frontend, so domains the app's ``Domain`` enum doesn't model (plant,
/// tag, …) still resolve the way the frontend does.
public enum EntityStateActive {
    public static let unavailable = "unavailable"
    public static let unknown = "unknown"

    /// `TIMESTAMP_STATE_DOMAINS` in `common/const.ts` — domains whose state is a timestamp, so any
    /// value other than `unavailable` means the entity is fine.
    public static let timestampStateDomains: Set<String> = [
        "ai_task",
        "button",
        "conversation",
        "event",
        "image",
        "infrared",
        "input_button",
        "notify",
        "radio_frequency",
        "scene",
        "stt",
        "tag",
        "tts",
        "wake_word",
        "datetime",
    ]

    /// - Parameters:
    ///   - domain: the entity's own domain, lowercased (`light`, `binary_sensor`, …).
    ///   - state: the raw entity state, lowercased.
    public static func isActive(domain: String, state: String) -> Bool {
        if timestampStateDomains.contains(domain) {
            return state != unavailable
        }

        if state == unavailable || state == unknown {
            return false
        }

        // "off" is inactive for most domains, but not for `alert`, where "off" only means the alert
        // was acknowledged and "idle" is the state that means nothing is going on.
        if state == "off", domain != "alert" {
            return false
        }

        switch domain {
        case "alarm_control_panel":
            return state != "disarmed"
        case "alert":
            return state != "idle"
        case "cover":
            return state != "closed"
        case "device_tracker", "person":
            return state != "not_home"
        case "lawn_mower":
            return !["docked", "paused"].contains(state)
        case "lock":
            return state != "locked"
        case "media_player":
            return state != "standby"
        case "vacuum":
            return !["idle", "docked", "paused"].contains(state)
        case "valve":
            return state != "closed"
        case "plant":
            return state == "problem"
        case "group":
            return ["on", "home", "open", "locked", "problem"].contains(state)
        case "timer":
            return state == "active"
        case "camera":
            return ["streaming", "recording"].contains(state)
        default:
            return true
        }
    }

    public static func isActive(domain: Domain?, state: String) -> Bool {
        isActive(domain: domain?.rawValue ?? "", state: state.lowercased())
    }
}
