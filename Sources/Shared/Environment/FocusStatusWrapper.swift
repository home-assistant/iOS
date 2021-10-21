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

        @available(iOS 15, watchOS 8, *)
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
        if #available(iOS 15, watchOS 8, *) {
            if Current.isAppExtension {
                return self?.lastStatus != nil
            } else {
                return true
            }
        } else {
            return false
        }
    }

    public var authorizationStatus: () -> AuthorizationStatus = {
        if #available(iOS 15, watchOS 8, *) {
            return .init(authorizationStatus: INFocusStatusCenter.default.authorizationStatus)
        }

        return .restricted
    }

    public var requestAuthorization: () -> Guarantee<AuthorizationStatus> = {
        let (promise, seal) = Guarantee<AuthorizationStatus>.pending()

        if #available(iOS 15, watchOS 8, *) {
            INFocusStatusCenter.default.requestAuthorization { result in
                seal(.init(authorizationStatus: result))
            }
        } else {
            seal(.restricted)
        }

        return promise
    }

    public struct Status: Equatable {
        public var isFocused: Bool?

        @available(iOS 15, watchOS 8, *)
        public init(focusStatus: INFocusStatus) {
            self.init(
                isFocused: focusStatus.isFocused
            )
        }

        public init(isFocused: Bool?) {
            self.isFocused = isFocused
        }
    }

    @available(iOS 15, watchOS 8, *)
    public func update(fromReceived status: INFocusStatus?) {
        precondition(Current.isAppExtension)
        lastStatus = status.flatMap { Status(focusStatus: $0) }
        trigger.value = Current.date()
    }

    public lazy var status: () -> Status = { [weak self] in
        if #available(iOS 15, watchOS 8, *) {
            if Current.isAppExtension, let lastStatus = self?.lastStatus {
                return lastStatus
            } else {
                return .init(focusStatus: INFocusStatusCenter.default.focusStatus)
            }
        }
        return .init(isFocused: nil)
    }
}
