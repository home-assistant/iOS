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
    /// Mirrors the pod's `WatchState` shape exactly so existing pattern-matching call sites compile
    /// unchanged after the swap.
    enum WatchState: Equatable {
        case paired(AppState)
        case notPaired

        public enum AppState: Equatable {
            case installed(ComplicationState, WatchSpecificLocalURL?)
            case notInstalled

            public enum ComplicationState: Equatable {
                case enabled(numberOfUpdatesAvailableToday: Int)
                case notEnabled
            }

            public typealias WatchSpecificLocalURL = URL
        }

        public var appState: AppState {
            switch self {
            case .notPaired: return .notInstalled
            case let .paired(appState): return appState
            }
        }

        public var complicationState: AppState.ComplicationState {
            switch appState {
            case .notInstalled: return .notEnabled
            case let .installed(complicationState, _): return complicationState
            }
        }

        public var numberOfComplicationUpdatesAvailableToday: Int {
            switch complicationState {
            case .notEnabled: return 0
            case let .enabled(numberAvailable): return numberAvailable
            }
        }
    }
    #endif
}
