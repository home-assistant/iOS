import Foundation

/// How far a folding device's hinge is open, as the system classifies it.
///
/// Mirrors UIKit's `UIHinge.Status`, kept as its own type so everything below the app target —
/// the sensor, its tests, the value sent to Home Assistant — is free of a symbol that only the
/// iOS 27.1 SDK has. The raw values are the sensor's state, so they are API: renaming one renames
/// the state Home Assistant has been storing.
public enum HingeStatus: String, CaseIterable, Sendable {
    /// The system cannot classify the hinge's position.
    case unknown
    /// The device is folded shut.
    case closed
    /// The device is somewhere between shut and open as far as it goes.
    case partiallyOpen = "partially_open"
    /// The device is open as far as the hardware allows.
    case fullyOpen = "fully_open"

    /// Maps UIKit's `UIHinge.Status` across by its raw value.
    ///
    /// The raw value rather than the type: `UIHinge.Status` only exists in the iOS 27.1 SDK, and
    /// taking the `Int` keeps this — and its tests — buildable and runnable everywhere else. The
    /// cases are frozen in UIKit's header, and anything unrecognised is `unknown`, which is what
    /// UIKit itself reports when it cannot classify the hinge.
    public init(uiKitStatusRawValue rawValue: Int) {
        switch rawValue {
        case 1:
            self = .closed
        case 2:
            self = .partiallyOpen
        case 3:
            self = .fullyOpen
        default:
            self = .unknown
        }
    }
}
