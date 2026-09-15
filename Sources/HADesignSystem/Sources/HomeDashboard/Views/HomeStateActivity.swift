#if !os(watchOS)
import Foundation

/// Whether a state counts as "doing something", which is what lets a tile's colour through.
///
/// A short form of the frontend's `state_active.ts`, covering the domains the home dashboard puts on
/// a card. `Shared`'s `EntityStateActive` is the full port, and the app hands that one in through
/// ``HomeEntityPresenter``; this is what the package draws with on its own.
public enum HomeStateActivity {
    public static func isActive(domain: String, state: String) -> Bool {
        if state == "unavailable" || state == "unknown" {
            return false
        }
        if state == "off" {
            return false
        }
        switch domain {
        case "alarm_control_panel": return state != "disarmed"
        case "camera": return ["streaming", "recording"].contains(state)
        case "cover", "valve": return state != "closed"
        case "device_tracker", "person": return state != "not_home"
        case "lock": return state != "locked"
        case "media_player": return state != "standby"
        case "vacuum": return !["idle", "docked", "paused"].contains(state)
        case "scene", "button", "input_button", "event": return true
        default: return true
        }
    }
}
#endif
