import Intents
import PromiseKit

public class FocusStatusWrapper {
    public enum AuthorizationStatus: Equatable {
        case notDetermined
        case restricted
        case denied
        case authorized

        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
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
        #endif
    }

    private var lastStatus: Status? {
        willSet {
            precondition(Current.isAppExtension)
        }
    }

    public lazy var isAvailable: () -> Bool = { [weak self] in
        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        if #available(iOS 15, watchOS 8, *) {
            if Current.isAppExtension {
                return self?.lastStatus != nil
            } else {
                return true
            }
        } else {
            return false
        }
        #else
        return false
        #endif
    }

    public var authorizationStatus: () -> AuthorizationStatus = {
        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        if #available(iOS 15, watchOS 8, *) {
            return .init(authorizationStatus: INFocusStatusCenter.default.authorizationStatus)
        }
        #endif

        return .restricted
    }

    public var requestAuthorization: () -> Guarantee<Void> = {
        let (promise, seal) = Guarantee<Void>.pending()

        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        if #available(iOS 15, watchOS 8, *) {
            INFocusStatusCenter.default.requestAuthorization { _ in
                seal(())
            }
        } else {
            seal(())
        }
        #else
        seal(())
        #endif

        return promise
    }

    public struct Status: Equatable {
        public var isFocused: Bool?

        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        @available(iOS 15, watchOS 8, *)
        public init(focusStatus: INFocusStatus) {
            self.init(
                isFocused: focusStatus.isFocused
            )
        }
        #endif

        public init(isFocused: Bool?) {
            self.isFocused = isFocused
        }
    }

    #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
    @available(iOS 15, watchOS 8, *)
    public func update(fromReceived status: INFocusStatus?) {
        precondition(Current.isAppExtension)
        lastStatus = status.flatMap { Status(focusStatus: $0) }
    }
    #endif

    public lazy var status: () -> Status = { [weak self] in
        #if compiler(>=5.5) && !targetEnvironment(macCatalyst)
        if #available(iOS 15, watchOS 8, *) {
            if Current.isAppExtension, let lastStatus = self?.lastStatus {
                return lastStatus
            } else {
                return .init(focusStatus: INFocusStatusCenter.default.focusStatus)
            }
        }
        #endif
        return .init(isFocused: nil)
    }
}
