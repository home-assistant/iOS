#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HealthKit

public extension HealthKitSleepStage {
    /// The raw `HKCategoryTypeIdentifier` every sleep metric reads.
    static let sleepAnalysisIdentifier = "HKCategoryTypeIdentifierSleepAnalysis"

    /// Maps the `value` of a sleep analysis sample, `nil` for a value this build doesn't know about.
    init?(sleepAnalysisValue: Int) {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: sleepAnalysisValue) else {
            return nil
        }

        switch value {
        case .inBed: self = .inBed
        case .asleepUnspecified: self = .asleepUnspecified
        case .awake: self = .awake
        case .asleepCore: self = .core
        case .asleepDeep: self = .deep
        case .asleepREM: self = .rem
        @unknown default: return nil
        }
    }
}
#endif
