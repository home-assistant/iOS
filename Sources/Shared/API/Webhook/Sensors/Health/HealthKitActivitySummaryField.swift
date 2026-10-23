#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// One number of a day's `HKActivitySummary`: how far a ring has got, or where it closes.
public enum HealthKitActivitySummaryField: Equatable, Hashable, Sendable {
    case progress(HealthKitActivityRing)
    case goal(HealthKitActivityRing)

    public var ring: HealthKitActivityRing {
        switch self {
        case let .progress(ring), let .goal(ring): return ring
        }
    }

    public var isGoal: Bool {
        if case .goal = self {
            return true
        }
        return false
    }
}
#endif
