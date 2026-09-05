#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
import HAKit
import HealthKit

public struct HealthKitService {
    /// Called when HealthKit reports new samples. It's handed HealthKit's completion handler, which must be
    /// called once the change has been dealt with: HealthKit keeps the app awake until then, and redelivers
    /// the change if it never comes.
    public typealias ChangeHandler = (_ completion: @escaping () -> Void) -> Void

    public enum HealthKitServiceError: LocalizedError, Equatable {
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

    /// Whether the Apple Health permission sheet was already presented to the user.
    ///
    /// HealthKit never discloses whether read access was granted, so the outcome can't be read back.
    /// What can be observed is that answering the sheet moves the requested types out of
    /// `.notDetermined`, which is enough to tell "never asked" apart from "already asked".
    public var hasRequestedReadAuthorization: () -> Bool = {
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension else {
            return false
        }

        // Deliberately the whole catalog rather than the enabled metrics: this answers "was the user
        // ever asked", which stays true after they turn every Apple Health sensor back off.
        return HealthKitService.readTypes(for: HealthKitMetric.all).contains {
            healthStore.authorizationStatus(for: $0) != .notDetermined
        }
    }

    /// Asks for read access to the enabled Apple Health sensors only, so the permission sheet stays as
    /// short as the user's selection instead of listing all of HealthKit.
    public var requestReadAuthorization: () async throws -> Void = {
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension else {
            throw HealthKitServiceError.unavailable
        }

        let types = HealthKitService.enabledReadTypes()

        guard !types.isEmpty else {
            throw HealthKitServiceError.noEnabledSensors
        }

        try await healthStore.requestAuthorization(toShare: Set<HKSampleType>(), read: types)
    }

    /// Reads a single metric over the given window, returning `nil` when the running OS doesn't know the
    /// metric, when it isn't authorized, or when there simply are no samples.
    public var queryValue: (HealthKitMetric, Date, Date) async throws -> Double? = { metric, start, end in
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension,
              let sampleType = HealthKitService.sampleType(for: metric) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        switch metric.aggregation {
        case let .sleep(stages):
            guard let categoryType = sampleType as? HKCategoryType else {
                return nil
            }
            return try await HealthKitService.sleepMinutes(in: stages, of: categoryType, predicate: predicate)
        case .cumulativeSum, .mostRecent:
            guard let quantityType = sampleType as? HKQuantityType,
                  let unit = metric.queryUnit.hkUnit,
                  quantityType.is(compatibleWith: unit) else {
                return nil
            }

            // A cumulative sum is only legal for cumulative types; anything else falls back to the newest
            // sample, so a mismatch in the catalog can't make HealthKit raise.
            if metric.aggregation == .cumulativeSum, quantityType.aggregationStyle == .cumulative {
                return try await HealthKitService.sum(of: quantityType, unit: unit, predicate: predicate)
            } else {
                return try await HealthKitService.mostRecent(of: quantityType, unit: unit, predicate: predicate)
            }
        }
    }

    /// Observes `metrics` in the background, calling `onChange` whenever HealthKit reports new samples for
    /// one of them. An empty list tears every observation down.
    public var setObservedMetrics: ([HealthKitMetric], @escaping ChangeHandler) -> Void = { metrics, onChange in
        guard HKHealthStore.isHealthDataAvailable(), !Current.isAppExtension else {
            return
        }

        HealthKitService.observations.update(
            to: HealthKitService.observableTypes(for: metrics),
            onChange: onChange
        )
    }

    public init() {}

    private static let observations = Observations()

    private static func sampleType(for metric: HealthKitMetric) -> HKSampleType? {
        sampleType(forIdentifier: metric.identifier)
    }

    private static func sampleType(forIdentifier identifier: String) -> HKSampleType? {
        if identifier == HealthKitSleepStage.sleepAnalysisIdentifier {
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        }
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: identifier))
    }

    /// May repeat a type, since every sleep metric reads the same one; callers dedupe.
    private static func observableTypes(for metrics: [HealthKitMetric]) -> [HKSampleType] {
        metrics
            .filter { $0.queryUnit.hkUnit != nil }
            .compactMap { sampleType(for: $0) }
    }

    /// The read types behind the metrics the user turned on. Enablement is an allowlist, so a metric
    /// nobody switched on is simply absent and never gets asked for.
    private static func enabledReadTypes() -> Set<HKObjectType> {
        readTypes(for: HealthKitMetric.all.filter { Current.sensors.isEnabled(uniqueID: $0.uniqueID) })
    }

    private static func readTypes(for metrics: [HealthKitMetric]) -> Set<HKObjectType> {
        let types: [HKObjectType] = observableTypes(for: metrics)
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

    /// Minutes spent in `stages` during the most recent night within `predicate`'s window.
    private static func sleepMinutes(
        in stages: Set<HealthKitSleepStage>,
        of categoryType: HKCategoryType,
        predicate: NSPredicate
    ) async throws -> Double? {
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: categoryType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.compactMap { $0 as? HKCategorySample } ?? [])
                }
            }
            healthStore.execute(query)
        }

        let sleepSamples = samples.compactMap { sample in
            HealthKitSleepStage(sleepAnalysisValue: sample.value).map {
                HealthKitSleepSample(start: sample.startDate, end: sample.endDate, stage: $0)
            }
        }

        return HealthKitSleepSummary
            .latestNight(in: sleepSamples, calendar: Current.calendar())?
            .minutes(in: stages)
    }

    /// Owns the running observer queries, keyed by sample type identifier.
    private final class Observations {
        private let activeQueries = HAProtected<[String: HKObserverQuery]>(value: [:])
        /// Kept apart from the queries so a query, which outlives the `update` that started it, always
        /// reports to the newest handler.
        private let changeHandler = HAProtected<ChangeHandler?>(value: nil)

        func update(to types: [HKSampleType], onChange: @escaping ChangeHandler) {
            let wanted = Set(types.map(\.identifier))
            changeHandler.mutate { $0 = onChange }

            activeQueries.mutate { queries in
                for (identifier, query) in queries.filter({ !wanted.contains($0.key) }) {
                    queries[identifier] = nil
                    stop(observing: identifier, query: query)
                }

                for type in types where queries[type.identifier] == nil {
                    queries[type.identifier] = start(observing: type)
                }
            }
        }

        private func start(observing type: HKSampleType) -> HKObserverQuery {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { [self] _, completionHandler, error in
                guard let error else {
                    reportChange(completionHandler)
                    return
                }
                // Left unanswered, HealthKit redelivers and eventually gives up on background delivery.
                Current.Log.error("health observer query for \(type.identifier) failed: \(error)")
                completionHandler()
            }

            HealthKitService.healthStore.execute(query)

            HealthKitService.healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, error in
                if let error {
                    Current.Log.error("failed enabling health background delivery for \(type.identifier): \(error)")
                }
            }

            return query
        }

        private func reportChange(_ completion: @escaping () -> Void) {
            guard let onChange = changeHandler.read({ $0 }) else {
                completion()
                return
            }
            onChange(completion)
        }

        private func stop(observing identifier: String, query: HKObserverQuery) {
            HealthKitService.healthStore.stop(query)

            guard let type = HealthKitService.sampleType(forIdentifier: identifier) else {
                return
            }

            HealthKitService.healthStore.disableBackgroundDelivery(for: type) { _, error in
                if let error {
                    Current.Log.error("failed disabling health background delivery for \(identifier): \(error)")
                }
            }
        }
    }
}
#endif
