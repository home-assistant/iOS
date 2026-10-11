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
#endif
