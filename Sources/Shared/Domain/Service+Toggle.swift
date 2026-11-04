import Foundation

public extension Service {
    /// What the customization screen calls this service when it is one side of a domain's on/off
    /// pair (`Domain.toggleServices`): "Lock" and "Unlock" for a lock, "Open" and "Close" for a
    /// cover or valve, "Turn on" and "Turn off" for the rest. `nil` for a service no domain
    /// toggles with.
    var toggleActionName: String? {
        switch self {
        case .turnOn:
            return L10n.Widgets.Action.Name.turnOn
        case .turnOff:
            return L10n.Widgets.Action.Name.turnOff
        case .openCover, .openValve:
            return L10n.Widgets.Action.Name.open
        case .closeCover, .closeValve:
            return L10n.Widgets.Action.Name.close
        case .lock:
            return L10n.Widgets.Action.Name.lock
        case .unlock:
            return L10n.Widgets.Action.Name.unlock
        default:
            return nil
        }
    }
}
