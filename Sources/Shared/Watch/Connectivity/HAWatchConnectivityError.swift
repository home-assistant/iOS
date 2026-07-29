import Foundation
import WatchConnectivity

public extension HAWatchConnectivity {
    enum ConnectivityError: LocalizedError {
        case sessionNotSupported
        case sessionNotActivated
        case notReachable
        case payloadTooLarge
        case payloadUnsupportedTypes
        case replyTimedOut
        case deliveryFailed(underlying: Error)

        public var errorDescription: String? {
            switch self {
            case .sessionNotSupported:
                return "WatchConnectivity is not supported on this device"
            case .sessionNotActivated:
                return "WatchConnectivity session is not activated"
            case .notReachable:
                return "The counterpart device is not immediately reachable"
            case .payloadTooLarge:
                return "The message payload exceeds the WatchConnectivity size limit"
            case .payloadUnsupportedTypes:
                return "The message payload contains non-property-list values"
            case .replyTimedOut:
                return "The counterpart did not reply in time"
            case let .deliveryFailed(underlying):
                return underlying.localizedDescription
            }
        }
    }
}

public extension HAWatchConnectivity.ConnectivityError {
    /// Whether `error` means "the counterpart wasn't reachable at that instant" rather than a real
    /// failure — either our own pre-send check (`.notReachable`) or WatchConnectivity's own
    /// `WCError.notReachable` (7007), which arrives wrapped in `.deliveryFailed` or raw depending on
    /// the call site.
    ///
    /// Reachability flaps constantly on watchOS: it can flip between a caller's pre-send check and the
    /// send itself, and the counterpart is usually back within a second. Callers use this to retry in
    /// the background instead of reporting a failure the user can't act on.
    static func isCounterpartUnreachable(_ error: Error) -> Bool {
        if let connectivityError = error as? Self {
            if case .notReachable = connectivityError {
                return true
            }
            if case let .deliveryFailed(underlying) = connectivityError {
                return isCounterpartUnreachable(underlying)
            }
            return false
        }
        let nsError = error as NSError
        return nsError.domain == WCErrorDomain && nsError.code == WCError.Code.notReachable.rawValue
    }
}

extension HAWatchConnectivity.ConnectivityError: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.sessionNotSupported, .sessionNotSupported),
             (.sessionNotActivated, .sessionNotActivated),
             (.notReachable, .notReachable),
             (.payloadTooLarge, .payloadTooLarge),
             (.payloadUnsupportedTypes, .payloadUnsupportedTypes),
             (.replyTimedOut, .replyTimedOut):
            return true
        case let (.deliveryFailed(lhsError), .deliveryFailed(rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}

extension HAWatchConnectivity.ConnectivityError: CustomNSError {
    public static var errorDomain: String { "HAWatchConnectivity" }

    public var errorCode: Int {
        switch self {
        case .sessionNotSupported: return 1
        case .sessionNotActivated: return 2
        case .notReachable: return 3
        case .payloadTooLarge: return 4
        case .payloadUnsupportedTypes: return 5
        case .replyTimedOut: return 6
        case .deliveryFailed: return 7
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: errorDescription ?? ""]
        if case let .deliveryFailed(underlying) = self {
            info[NSUnderlyingErrorKey] = underlying as NSError
        }
        return info
    }
}
