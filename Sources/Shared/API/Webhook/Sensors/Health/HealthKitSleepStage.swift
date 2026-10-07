#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// One of the states a sleep analysis sample can record, mirroring `HKCategoryValueSleepAnalysis`.
/// Kept free of `HealthKit` types so the metric catalog stays plain data;
/// `HealthKitSleepStage+HealthKit` does the translation when a query runs.
public enum HealthKitSleepStage: String, CaseIterable, Sendable {
    case inBed
    /// Asleep, without the source saying in which stage: every sample written before iOS 16, and
    /// what most third-party sleep trackers still record.
    case asleepUnspecified
    case awake
    case core
    case deep
    case rem

    /// The stages that count as being asleep, which together make up the total sleep duration.
    public static let asleepStages: Set<HealthKitSleepStage> = [.asleepUnspecified, .core, .deep, .rem]

    /// The stages a source that records this one also records, so a night without any of them means
    /// the source doesn't track them, while a night with some of them and none of this one means
    /// zero minutes. Apple Watch writes awake, core, deep and REM as a set; nothing else comes in a set.
    public var recordedAlongside: Set<HealthKitSleepStage> {
        switch self {
        case .inBed: return [.inBed]
        case .asleepUnspecified: return [.asleepUnspecified]
        case .awake, .core, .deep, .rem: return [.awake, .core, .deep, .rem]
        }
    }
}
#endif
