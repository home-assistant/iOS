import Foundation
import HealthKit
@testable import Shared
import SharedTesting
import Testing

/// Drives `HealthKitService`'s default closures against the real `HKHealthStore`. A test bundle has no
/// HealthKit entitlement, so every query ends in an error or an empty answer; what matters is that each
/// path completes (no hung continuation) and reports `nil` or throws rather than crashing.
@Suite(.sharedState, .timeLimit(.minutes(1)))
struct HealthKitServiceStoreTests {
    private let service = HealthKitService()
    private let start = Date(timeIntervalSince1970: 1_780_000_000)
    private var end: Date { start.addingTimeInterval(86400) }

    private func metric(matching predicate: (HealthKitMetricAggregation) -> Bool) throws -> HealthKitMetric {
        try #require(HealthKitMetric.all.first { predicate($0.aggregation) })
    }

    /// Either outcome is fine; the query only has to come back.
    private func settle(_ metric: HealthKitMetric) async -> Bool {
        do {
            _ = try await service.queryValue(metric, start, end)
        } catch {
            #expect(!error.localizedDescription.isEmpty)
        }
        return true
    }

    @Test func errorsDescribeThemselves() {
        #expect(HealthKitService.HealthKitServiceError.unavailable.errorDescription?.isEmpty == false)
        #expect(HealthKitService.HealthKitServiceError.noEnabledSensors.errorDescription?.isEmpty == false)
        #expect(HealthKitService.HealthKitServiceError.unavailable != .noEnabledSensors)
    }

    @Test func availabilityAndAuthorizationQueriesAnswer() async {
        _ = service.isAvailable()
        _ = service.hasRequestedReadAuthorization()
        do {
            try await service.requestReadAuthorization()
        } catch {
            #expect(!error.localizedDescription.isEmpty)
        }
    }

    @Test func cumulativeQueryCompletes() async throws {
        let metric = try metric { $0 == .cumulativeSum }
        let settled = await settle(metric)
        #expect(settled)
    }

    @Test func mostRecentQueryCompletes() async throws {
        let metric = try metric { $0 == .mostRecent }
        let settled = await settle(metric)
        #expect(settled)
    }

    @Test func sleepQueryCompletes() async throws {
        let metric = try metric {
            if case .sleep = $0 { return true }
            return false
        }
        let settled = await settle(metric)
        #expect(settled)
    }

    @Test func activitySummaryReadsThroughTheInjectedSummaries() async throws {
        let metric = try metric {
            if case .activitySummary = $0 { return true }
            return false
        }
        let previous = Current.healthKitService
        // Outside a host app `Current.isAppExtension` starts out true (the bundle isn't the app's), and
        // an extension never queries HealthKit; earlier classes that set it false leave it either way.
        let previousIsAppExtension = Current.isAppExtension
        defer {
            Current.healthKitService = previous
            Current.isAppExtension = previousIsAppExtension
        }
        Current.isAppExtension = false
        var requested: [(DateComponents, DateComponents)] = []
        Current.healthKitService.activitySummaries = { start, end in
            requested.append((start, end))
            return []
        }

        let value = try await service.queryValue(metric, start, end)
        if HKHealthStore.isHealthDataAvailable() {
            #expect(value == nil)
            #expect(requested.count == 1)
        }
    }

    @Test func observingMetricsStartsAndStopsQueries() throws {
        let observed = Array(HealthKitMetric.all.prefix(3))
        service.setObservedMetrics(observed) { completion in completion() }
        service.setObservedMetrics(Array(observed.prefix(1))) { completion in completion() }
        service.setObservedMetrics([]) { completion in completion() }
        #expect(HealthKitService.observableTypes(for: []).isEmpty)
    }
}
