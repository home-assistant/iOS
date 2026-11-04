import Intents
import PromiseKit

/// iOS's answer to whether a Focus is on, from the two places it gives one.
///
/// - The `INShareFocusStatusIntent` iOS hands the Intents extension when the status changes.
///   Apple's sample reads the value from the intent there, not from `INFocusStatusCenter`, which
///   in an extension answers "not focused" whatever is on.
/// - `INFocusStatusCenter`, which the app asks itself every time it reads the Focus sensors.
///
/// Both answers are stored in the app group with when they were given, and the newest one is the
/// status. A push can be hours old by the time something reads it, since iOS doesn't reliably
/// deliver the one for a Focus ending, while the app's reading is as fresh as its last sensor
/// read. The other extensions, such as the push provider, can't ask iOS at all, so they report
/// what the newest answer said instead of an older push that the app has since seen past.
///
/// `isFocused` is `true` while a Focus that silences this app is on. It is `false` otherwise,
/// including while the Focus that is on allows this app's notifications or doesn't share its
/// status. Which Focus is on, and whether one iOS reports as not focused is on, is the Focus
/// Filter's to say.
public class FocusStatusWrapper {
    public enum AuthorizationStatus: Equatable {
        case notDetermined
        case restricted
        case denied
        case authorized

        init(authorizationStatus: INFocusStatusAuthorizationStatus) {
            switch authorizationStatus {
            case .notDetermined:
                self = .notDetermined
            case .restricted:
                self = .restricted
            case .denied:
                self = .denied
            case .authorized:
                self = .authorized
            @unknown default:
                self = .denied
            }
        }
    }

    /// Every status iOS pushed to the Intents extension. Observed by the Focus sensors, because a
    /// push is iOS saying the status changed.
    private(set) lazy var pushes = UserDefaultsValueSync<FocusStatusObservation>(settingsKey: "FocusStatusStateKey")

    /// The app's own last reading. Not observed: every sensor read writes it, so observing it
    /// would make each read start the next one.
    private(set) lazy var readings = UserDefaultsValueSync<FocusStatusObservation>(
        settingsKey: "FocusStatusReadingKey"
    )

    /// Whether this device has Focus at all. Every OS version the app supports does.
    public var isAvailable: () -> Bool = { true }

    public var authorizationStatus: () -> AuthorizationStatus = {
        .init(authorizationStatus: INFocusStatusCenter.default.authorizationStatus)
    }

    public var requestAuthorization: () -> Guarantee<AuthorizationStatus> = {
        let (promise, seal) = Guarantee<AuthorizationStatus>.pending()

        INFocusStatusCenter.default.requestAuthorization { result in
            seal(.init(authorizationStatus: result))
        }

        return promise
    }

    /// Whether this process can ask iOS for the status. Only the app can: in an extension
    /// `INFocusStatusCenter` answers "not focused" whatever is on.
    public var canAskIOS: () -> Bool = { !Current.isAppExtension }

    /// iOS's live answer, `nil` without the Focus status permission.
    public var liveIsFocused: () -> Bool? = {
        INFocusStatusCenter.default.focusStatus.isFocused
    }

    /// Stores what iOS pushed to the Intents extension.
    ///
    /// A push without a value is skipped, as Apple's sample does: iOS only leaves the value out
    /// for an app without the permission, and the app's own reading already says that.
    public func record(pushed focusStatus: INFocusStatus?) {
        guard let isFocused = focusStatus?.isFocused else {
            Current.Log.info("focus status push carried no value, keeping the previous status")
            return
        }
        pushes.value = FocusStatusObservation(isFocused: isFocused, date: Current.date())
    }

    /// Asks iOS for the status and stores the answer, when this process can ask.
    ///
    /// Without the permission iOS doesn't answer, and that is stored too: a push from before the
    /// permission was revoked would otherwise keep reporting a status nothing updates anymore.
    func readFromIOS() {
        guard canAskIOS() else { return }
        let isFocused = authorizationStatus() == .authorized ? liveIsFocused() : nil
        readings.value = FocusStatusObservation(isFocused: isFocused, date: Current.date())
    }

    /// The newest answer iOS gave, from whichever process received it.
    public lazy var latest: () -> FocusStatusObservation? = { [weak self] in
        guard let self else { return nil }
        return Self.newest(pushes.value, readings.value)
    }

    private static func newest(
        _ lhs: FocusStatusObservation?,
        _ rhs: FocusStatusObservation?
    ) -> FocusStatusObservation? {
        guard let lhs else { return rhs }
        guard let rhs else { return lhs }
        return rhs.date >= lhs.date ? rhs : lhs
    }
}
