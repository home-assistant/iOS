#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HealthKit

public struct HealthKitService {
    public enum HealthKitServiceError: LocalizedError {
        case unavailable
        case noEnabledSensors

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return L10n.SettingsSensors.Health.Error.unavailable
            case .noEnabledSensors:
                return L10n.SettingsSensors.Health.Error.noEnabledSensors
            }
        }
    }

    private static let healthStore = HKHealthStore()

    public var isAvailable: () -> Bool = {
        HKHealthStore.isHealthDataAvailable() && !Current.isAppExtension
    }

    /// Asks for read access to the enabled Apple Health sensors only, so the permission sheet stays as
    /// short as the user's selection instead of listing all of HealthKit.
    public var requestReadAuthorization: () async throws -> Void = {
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension else {
            throw HealthKitServiceError.unavailable
        }

        let enabled = HealthKitMetric.all.filter { Current.sensors.isEnabled(uniqueID: $0.uniqueID) }
        let types = HealthKitService.readTypes(for: enabled)

        guard !types.isEmpty else {
            throw HealthKitServiceError.noEnabledSensors
        }

        try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: types)
    }

    /// Reads a single metric over the given window, returning `nil` when the running OS doesn't know the
    /// metric, when it isn't authorized, or when there simply are no samples.
    public var queryValue: (HealthKitMetric, Date, Date) async throws -> Double? = { metric, start, end in
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension,
              let quantityType = HealthKitService.quantityType(for: metric),
              let unit = metric.queryUnit.hkUnit,
              quantityType.is(compatibleWith: unit) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        // A cumulative sum is only legal for cumulative types; anything else falls back to the newest
        // sample, so a mismatch in the catalog can't make HealthKit raise.
        if metric.aggregation == .cumulativeSum, quantityType.aggregationStyle == .cumulative {
            return try await HealthKitService.sum(of: quantityType, unit: unit, predicate: predicate)
        } else {
            return try await HealthKitService.mostRecent(of: quantityType, unit: unit, predicate: predicate)
        }
    }

    public init() {}

    private static func quantityType(for metric: HealthKitMetric) -> HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: metric.identifier))
    }

    private static func readTypes(for metrics: [HealthKitMetric]) -> Set<HKObjectType> {
        let types: [HKObjectType] = metrics
            .filter { $0.queryUnit.hkUnit != nil }
            .compactMap { quantityType(for: $0) }
        return Set(types)
    }

    private static func sum(
        of quantityType: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double? {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
                }
            }
            healthStore.execute(query)
        }
    }

    private static func mostRecent(
        of quantityType: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let sample = samples?.first as? HKQuantitySample
                    continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
                }
            }
            healthStore.execute(query)
        }
    }
}
#endif
