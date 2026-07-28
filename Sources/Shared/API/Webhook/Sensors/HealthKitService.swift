#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HealthKit

public struct HealthKitService {
    public enum HealthKitServiceError: LocalizedError {
        case unavailable

        public var errorDescription: String? {
            switch self {
            case .unavailable:
                return L10n.SettingsSensors.Health.Error.unavailable
            }
        }
    }

    private static let healthStore = HKHealthStore()

    public var isAvailable: () -> Bool = {
        HKHealthStore.isHealthDataAvailable() && !Current.isAppExtension
    }

    public var requestReadAuthorization: () async throws -> Void = {
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension else {
            throw HealthKitServiceError.unavailable
        }

        try await healthStore.requestAuthorization(
            toShare: Set<HKSampleType>(),
            read: healthDataTypes()
        )
    }

    public var queryStepCount: (Date, Date) async throws -> Int? = { start, end in
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension,
              let quantityType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let steps = statistics?.sumQuantity()?.doubleValue(for: .count())
                    continuation.resume(returning: steps.map(Int.init))
                }
            }
            healthStore.execute(query)
        }
    }

    public var queryLatestRestingHeartRate: (Date, Date) async throws -> Double? = { start, end in
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension,
              let quantityType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
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
                    let unit = HKUnit.count().unitDivided(by: .minute())
                    continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
                }
            }
            healthStore.execute(query)
        }
    }

    public init() {}

    private static func healthDataTypes() -> Set<HKObjectType> {
        Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
        ].compactMap { $0 })
    }
}
#endif
