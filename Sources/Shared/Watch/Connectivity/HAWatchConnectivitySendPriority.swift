import Foundation

public extension HAWatchConnectivity {
    /// Ordering of queued interactive sends once the in-flight cap is reached: user-visible
    /// actions jump ahead of routine refreshes, which jump ahead of bulk syncs.
    enum SendPriority: Int, Comparable {
        case background = 0
        case normal = 1
        case userAction = 2

        public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    }
}
