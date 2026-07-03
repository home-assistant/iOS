import Foundation

public extension HAWatchConnectivity {
    enum Reachability: Equatable {
        case immediatelyReachable
        case notReachable
    }

    enum SessionState: Equatable {
        case notActivated
        case inactive
        case activated
    }

    #if os(iOS)
    enum WatchState: Equatable {
        public enum AppInstalledState: Equatable {
            case notInstalled
            case installed
            case enabled(numberOfComplicationUpdatesAvailableToday: Int)
        }

        case notPaired
        case paired(AppInstalledState)

        public var isPaired: Bool {
            switch self {
            case .notPaired: return false
            case .paired: return true
            }
        }

        public var isAppInstalled: Bool {
            switch self {
            case .notPaired, .paired(.notInstalled): return false
            case .paired(.installed), .paired(.enabled): return true
            }
        }
    }
    #endif
}
