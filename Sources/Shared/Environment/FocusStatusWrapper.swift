import Intents
import PromiseKit

/// The Focus status iOS last pushed to us, kept in the app group so every process reads the same
/// thing instead of asking iOS itself, along with when a Focus last ended — which is what decides
/// whether the name the Focus Filter reported is still the Focus that is running.
public struct FocusStatusState: Codable, Equatable {
    /// Whether any Focus was running, or `nil` when iOS sent a status without saying.
    public var isFocused: Bool?
    /// When this status arrived, so pushing the same status twice still notifies observers.
    public var date: Date
    /// When iOS last said every Focus had ended, kept across later updates. A name the filter
    /// reported before that moment belongs to a Focus that is over; one reported after it doesn't.
    public var lastEndedDate: Date?

    public init(isFocused: Bool?, date: Date, lastEndedDate: Date?) {
        self.isFocused = isFocused
        self.date = date
        self.lastEndedDate = lastEndedDate
    }
}

public class FocusStatusStateSync: UserDefaultsValueSync<FocusStatusState> {
    init() {
        super.init(settingsKey: "FocusStatusStateKey")
    }
}

public class FocusStatusWrapper {
    /// Every Focus status iOS pushed us, in the app group. Observed to signal the Focus sensors,
    /// and read back by `FocusReport` to decide whether a reported name is still current.
    private(set) lazy var receivedStatus = FocusStatusStateSync()

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

    private var lastStatus: Status? {
        willSet {
            precondition(Current.isAppExtension)
        }
    }

    public lazy var isAvailable: () -> Bool = { [weak self] in
        if Current.isAppExtension {
            return self?.lastStatus != nil
        } else {
            return true
        }
    }

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

    public struct Status: Equatable {
        public var isFocused: Bool?

        public init(focusStatus: INFocusStatus) {
            self.init(
                isFocused: focusStatus.isFocused
            )
        }

        public init(isFocused: Bool?) {
            self.isFocused = isFocused
        }
    }

    public func update(fromReceived status: INFocusStatus?) {
        precondition(Current.isAppExtension)
        lastStatus = status.flatMap { Status(focusStatus: $0) }

        let now = Current.date()
        let isFocused = lastStatus?.isFocused

        // Recorded rather than acted on: iOS runs the next Focus' filter before it tells us the
        // previous one ended, so which of the two is current is decided when they are read back
        // together, not by letting whichever arrives last overwrite the other.
        receivedStatus.value = FocusStatusState(
            isFocused: isFocused,
            date: now,
            lastEndedDate: isFocused == false ? now : receivedStatus.value?.lastEndedDate
        )
    }

    public lazy var status: () -> Status = { [weak self] in
        if Current.isAppExtension, let lastStatus = self?.lastStatus {
            return lastStatus
        } else {
            return .init(focusStatus: INFocusStatusCenter.default.focusStatus)
        }
    }

    /// The last status iOS pushed us, from whichever process received it.
    public lazy var lastReceived: () -> FocusStatusState? = { [weak self] in
        self?.receivedStatus.value
    }
}
