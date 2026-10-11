#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// One of the three rings the Fitness app draws. Kept free of `HealthKit` types so the metric catalog
/// stays plain data; `HealthKitActivityRing+HealthKit` reads a ring out of an `HKActivitySummary`.
public enum HealthKitActivityRing: String, CaseIterable, Sendable {
    /// Active energy burned, in kilocalories.
    case move
    /// Exercise minutes.
    case exercise
    /// Hours with at least a minute spent standing, or rolling for wheelchair users.
    case stand
}

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
