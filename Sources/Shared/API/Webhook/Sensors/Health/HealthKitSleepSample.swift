#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// One sleep analysis sample, reduced to what `HealthKitSleepSummary` needs.
public struct HealthKitSleepSample: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let stage: HealthKitSleepStage

    public init(start: Date, end: Date, stage: HealthKitSleepStage) {
        self.start = start
        self.end = end
        self.stage = stage
    }
}
#endif
