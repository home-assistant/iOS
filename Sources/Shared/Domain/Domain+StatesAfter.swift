import Foundation

public extension Domain {
    /// The states that show `service` took effect, including the one an entity passes through on
    /// the way.
    ///
    /// Home Assistant answers a service call as soon as it has passed it on, not once the device
    /// has reported back, so anything that wants to show the result has to know which states to
    /// wait for. A curtain reads `closing` for as long as it is travelling and only reaches
    /// `closed` at the end of it, which is far longer than anyone will wait for a card — but
    /// `closing` already proves the command landed, so it counts.
    ///
    /// Empty where there is nothing worth waiting for: a scene or a button records the time it last
    /// ran rather than a state, a script only reads `on` for as long as it is running, and a
    /// service that changes an attribute leaves the state alone.
    func statesAfter(_ service: Service) -> [String] {
        switch self {
        case .scene, .button, .inputButton, .script:
            // These record when they last ran, not what they became.
            return []
        default:
            break
        }

        switch service {
        case .turnOn:
            return ["on"]
        case .turnOff:
            return ["off"]
        case .openCover, .openValve:
            return ["open", "opening"]
        case .closeCover, .closeValve:
            return ["closed", "closing"]
        case .lock:
            return ["locked", "locking"]
        case .unlock:
            return ["unlocked", "unlocking"]
        default:
            return []
        }
    }
}
