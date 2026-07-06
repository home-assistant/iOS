import Foundation

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
