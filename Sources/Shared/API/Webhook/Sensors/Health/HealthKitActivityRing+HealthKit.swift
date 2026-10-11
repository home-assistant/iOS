#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HealthKit

public extension HealthKitActivityRing {
    /// The sample type whose new samples move this ring. An activity summary can't be observed or
    /// delivered in the background itself, so this stands in for it.
    var progressSampleType: HKSampleType {
        switch self {
        case .move: return HKQuantityType(.activeEnergyBurned)
        case .exercise: return HKQuantityType(.appleExerciseTime)
        case .stand: return HKCategoryType(.appleStandHour)
        }
    }

    func progress(in summary: HKActivitySummary) -> HKQuantity {
        switch self {
        case .move: return summary.activeEnergyBurned
        case .exercise: return summary.appleExerciseTime
        case .stand: return summary.appleStandHours
        }
    }

    func goal(in summary: HKActivitySummary) -> HKQuantity {
        switch self {
        case .move: return summary.activeEnergyBurnedGoal
        case .exercise: return summary.appleExerciseTimeGoal
        case .stand: return summary.appleStandHoursGoal
        }
    }
}

public extension HealthKitActivitySummaryField {
    /// The raw `HKActivitySummaryType` identifier, which every activity ring metric reads from.
    static let identifier = "HKActivitySummaryTypeIdentifier"

    /// What to observe for background delivery of this field: the ring's sample type for its progress,
    /// nothing for a goal. Changing a goal in Fitness writes no sample, so there is nothing to observe;
    /// goals pick up their new value on the next periodic update, or on the next delivery for a
    /// progress sensor the user also switched on. Observing the progress type for a goal would only
    /// wake the app to re-read a constant, and put a type the user didn't choose on the permission
    /// sheet.
    var observedSampleTypes: [HKSampleType] {
        switch self {
        case let .progress(ring): return [ring.progressSampleType]
        case .goal: return []
        }
    }

    /// This field of `summary` in `unit`, or `nil` when the ring isn't being tracked.
    ///
    /// A ring nobody is tracking — Exercise and Stand without an Apple Watch — comes back with a goal
    /// of zero, and its progress is then a zero that was never measured. A Move ring set to move time
    /// rather than energy, the mode Fitness offers younger users and wheelchair users, may still carry
    /// energy numbers, but they aren't the ring. None of that is reported: an untracked ring and its
    /// goal both stay unavailable.
    func value(in summary: HKActivitySummary, unit: HKUnit) -> Double? {
        let goal = ring.goal(in: summary)
        let progress = ring.progress(in: summary)
        guard goal.is(compatibleWith: unit), progress.is(compatibleWith: unit),
              isTracked(in: summary, goal: goal, unit: unit) else {
            return nil
        }

        switch self {
        case .progress: return progress.doubleValue(for: unit)
        case .goal: return goal.doubleValue(for: unit)
        }
    }

    /// `goal` must already be known to be compatible with `unit`.
    private func isTracked(in summary: HKActivitySummary, goal: HKQuantity, unit: HKUnit) -> Bool {
        if ring == .move, summary.activityMoveMode != .activeEnergy {
            return false
        }
        return goal.doubleValue(for: unit) > 0
    }
}
#endif
