#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Explanatory text shown under one sensor in the Apple Health sensor list, for a metric whose
/// availability depends on something the user has to set up outside this app.
///
/// A case rather than a string, so the metric catalog stays plain data — like
/// `HealthKitMetricCategory`, the wording is resolved in the user's current language when it's read.
public enum HealthKitMetricFooter: String, CaseIterable, Sendable {
    /// Nothing writes `inBed` samples on its own: Apple Watch records the sleep stages but not time in
    /// bed, so "In Bed" reads as unavailable until the user turns iPhone tracking on or installs a
    /// sleep app that records it.
    case timeInBedSource
    /// Only an Apple Watch tracks the Exercise and Stand rings; without one their sensors read as
    /// unavailable. See `HealthKitActivitySummaryField.value(in:unit:)`.
    case ringNeedsWatch
    /// The Move goal is reported in kilocalories, so it reads as unavailable while the Move ring is set
    /// to move time.
    case moveGoalEnergyOnly

    public var text: String {
        switch self {
        case .timeInBedSource: return L10n.SettingsSensors.Health.Metric.InBed.footer
        case .ringNeedsWatch: return L10n.SettingsSensors.Health.Metric.RingNeedsWatch.footer
        case .moveGoalEnergyOnly: return L10n.SettingsSensors.Health.Metric.MoveGoal.footer
        }
    }
}
#endif
