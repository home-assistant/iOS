import Intents
import PromiseKit

public class FocusStateTrigger: UserDefaultsValueSync<Date> {
    init() {
        super.init(settingsKey: "FocusStateTriggerKey")
    }
}

public class FocusStatusWrapper {
    private(set) lazy var trigger = FocusStateTrigger()

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
        trigger.value = Current.date()
    }

    public lazy var status: () -> Status = { [weak self] in
        if Current.isAppExtension, let lastStatus = self?.lastStatus {
            return lastStatus
        } else {
            return .init(focusStatus: INFocusStatusCenter.default.focusStatus)
        }
    }
}
