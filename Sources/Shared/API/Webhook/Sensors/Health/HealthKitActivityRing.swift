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
#endif
