import Foundation
import HealthKit
@testable import Shared
import XCTest

/// The catalog stores HealthKit identifiers as raw strings so metrics newer than the deployment target
/// can be listed unconditionally. These tests are what keeps that honest: everything the running OS
/// knows about has to resolve, and has to line up with the unit and aggregation the catalog claims.
class HealthKitMetricCatalogTests: XCTestCase {
    private func isAvailableOnThisOS(_ metric: HealthKitMetric) -> Bool {
        ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(
            majorVersion: metric.availableFromIOS,
            minorVersion: 0,
            patchVersion: 0
        ))
    }

    private func quantityType(for metric: HealthKitMetric) -> HKQuantityType? {
        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: metric.identifier))
    }

    private func isSleepMetric(_ metric: HealthKitMetric) -> Bool {
        if case .sleep = metric.aggregation {
            return true
        }
        return false
    }

    private func isActivityRingMetric(_ metric: HealthKitMetric) -> Bool {
        metric.aggregation.activitySummaryField != nil
    }

    func testCatalogIsNotEmptyAndCoversEveryCategory() {
        XCTAssertGreaterThan(HealthKitMetric.all.count, 20)
        for category in HealthKitMetricCategory.allCases {
            XCTAssertFalse(HealthKitMetric.metrics(in: category).isEmpty, category.rawValue)
        }
    }

    func testUniqueIDsAreUniqueAndPrefixed() {
        var seen = Set<String>()
        for metric in HealthKitMetric.all {
            XCTAssertTrue(metric.uniqueID.hasPrefix("health_"), metric.uniqueID)
            XCTAssertTrue(seen.insert(metric.uniqueID).inserted, "duplicate \(metric.uniqueID)")
            XCTAssertEqual(HealthKitMetric.metric(uniqueID: metric.uniqueID), metric)
        }
    }

    func testHealthKitIdentifiersAreUniqueAndResolveOnThisOS() {
        var seen = Set<String>()
        for metric in HealthKitMetric.all where !isSleepMetric(metric) && !isActivityRingMetric(metric) {
            XCTAssertTrue(
                metric.identifier.hasPrefix("HKQuantityTypeIdentifier"),
                metric.identifier
            )
            XCTAssertTrue(seen.insert(metric.identifier).inserted, "duplicate \(metric.identifier)")

            guard isAvailableOnThisOS(metric) else { continue }
            XCTAssertNotNil(quantityType(for: metric), metric.identifier)
        }
    }

    func testSleepMetricsShareTheSleepAnalysisTypeAndCoverDistinctStages() {
        let sleepMetrics = HealthKitMetric.all.filter { isSleepMetric($0) }
        XCTAssertEqual(sleepMetrics.map(\.uniqueID), HealthKitMetric.sleepMetrics.map(\.uniqueID))

        var seen = Set<HealthKitMetricAggregation>()
        for metric in sleepMetrics {
            XCTAssertEqual(metric.identifier, HealthKitSleepStage.sleepAnalysisIdentifier)
            XCTAssertEqual(metric.category, .sleep)
            XCTAssertEqual(metric.unit, "min")
            XCTAssertEqual(metric.deviceClass, .duration)
            XCTAssertTrue(seen.insert(metric.aggregation).inserted, "duplicate \(metric.uniqueID)")
        }

        let identifier = HKCategoryTypeIdentifier(rawValue: HealthKitSleepStage.sleepAnalysisIdentifier)
        XCTAssertNotNil(HKObjectType.categoryType(forIdentifier: identifier))
    }

    func testSleepDurationCoversEveryAsleepStageAndEachStageHasASensor() throws {
        let duration = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_sleep_duration"))
        XCTAssertEqual(duration.aggregation, .sleep(stages: [.asleepUnspecified, .core, .deep, .rem]))

        for (uniqueID, stage) in [
            ("health_sleep_in_bed", HealthKitSleepStage.inBed),
            ("health_sleep_awake", .awake),
            ("health_sleep_core", .core),
            ("health_sleep_deep", .deep),
            ("health_sleep_rem", .rem),
        ] {
            let metric = try XCTUnwrap(HealthKitMetric.metric(uniqueID: uniqueID))
            XCTAssertEqual(metric.aggregation, .sleep(stages: [stage]), uniqueID)
        }
    }

    func testOnlyMetricsThatNeedAnotherSourceCarryAFooter() throws {
        // Nothing writes `inBed` samples on its own, and the Move goal is energy only, so those are the
        // sensors whose row has to explain why they can read as unavailable.
        let footers = [
            "health_sleep_in_bed": HealthKitMetricFooter.timeInBedSource,
            "health_active_energy_burned_goal": .moveGoalEnergyOnly,
        ]

        for metric in HealthKitMetric.all {
            XCTAssertEqual(metric.footer, footers[metric.uniqueID], metric.uniqueID)
        }
    }

    func testOnlyTheExerciseAndStandRingSensorsRequireAnAppleWatch() {
        // Only an Apple Watch tracks those rings, so their rows carry the badge; the Move goal exists
        // on an iPhone alone.
        let watchOnly = HealthKitMetric.all.filter(\.requiresAppleWatch).map(\.uniqueID)

        XCTAssertEqual(
            Set(watchOnly),
            ["health_apple_exercise_time_goal", "health_apple_stand_hours", "health_apple_stand_hours_goal"]
        )
    }

    func testEveryFooterResolvesToText() {
        for footer in HealthKitMetricFooter.allCases {
            XCTAssertFalse(footer.text.isEmpty, footer.rawValue)
        }
    }

    func testActivityRingMetricsReadTheActivitySummaryAndCoverEveryGoal() throws {
        let rings = HealthKitMetric.all.filter { isActivityRingMetric($0) }
        XCTAssertEqual(rings.map(\.uniqueID), HealthKitMetric.activityRingMetrics.map(\.uniqueID))

        var seen = Set<HealthKitActivitySummaryField>()
        for metric in rings {
            XCTAssertEqual(metric.identifier, HealthKitActivitySummaryField.identifier, metric.uniqueID)
            XCTAssertEqual(metric.category, .activity, metric.uniqueID)
            XCTAssertEqual(metric.decimalPlaces, 0, metric.uniqueID)
            let field = try XCTUnwrap(metric.aggregation.activitySummaryField)
            XCTAssertTrue(seen.insert(field).inserted, "duplicate \(metric.uniqueID)")
        }

        for ring in HealthKitActivityRing.allCases {
            XCTAssertTrue(seen.contains(.goal(ring)), ring.rawValue)
        }
        // Move and Exercise progress are the existing sample-based sensors; only Stand has no
        // quantity type to sum, so it's the one ring read from the summary.
        XCTAssertEqual(seen.filter { !$0.isGoal }, [.progress(.stand)])
    }

    func testEachGoalMatchesTheSensorItIsTheGoalFor() throws {
        for (progressID, goalID, ring) in [
            ("health_active_energy_burned", "health_active_energy_burned_goal", HealthKitActivityRing.move),
            ("health_apple_exercise_time", "health_apple_exercise_time_goal", .exercise),
            ("health_apple_stand_hours", "health_apple_stand_hours_goal", .stand),
        ] {
            let progress = try XCTUnwrap(HealthKitMetric.metric(uniqueID: progressID))
            let goal = try XCTUnwrap(HealthKitMetric.metric(uniqueID: goalID))

            XCTAssertEqual(goal.aggregation, .activitySummary(.goal(ring)), goalID)
            XCTAssertEqual(progress.unit, goal.unit, goalID)
            XCTAssertEqual(progress.queryUnit, goal.queryUnit, goalID)
            XCTAssertEqual(progress.deviceClass, goal.deviceClass, goalID)
            // Progress resets daily like the other totals; a goal is a setting that can be lowered.
            XCTAssertEqual(progress.stateClass, .totalIncreasing, progressID)
            XCTAssertEqual(goal.stateClass, .measurement, goalID)
        }
    }

    func testStandHoursAreCountedInHours() throws {
        let stand = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_apple_stand_hours"))
        XCTAssertEqual(stand.aggregation, .activitySummary(.progress(.stand)))
        XCTAssertEqual(stand.name, "Stand Hours")
        XCTAssertEqual(stand.unit, "hours")
        XCTAssertEqual(stand.queryUnit, .count)
        XCTAssertNil(stand.deviceClass)
    }

    func testUnitsAreCompatibleWithTheirQuantityType() {
        for metric in HealthKitMetric.all
            where isAvailableOnThisOS(metric) && !isSleepMetric(metric) && !isActivityRingMetric(metric) {
            guard let type = quantityType(for: metric), let unit = metric.queryUnit.hkUnit else { continue }
            XCTAssertTrue(type.is(compatibleWith: unit), "\(metric.identifier) / \(unit)")
        }
    }

    func testCumulativeMetricsUseCumulativeQuantityTypes() {
        for metric in HealthKitMetric.all where metric.aggregation == .cumulativeSum {
            guard isAvailableOnThisOS(metric), let type = quantityType(for: metric) else { continue }
            XCTAssertEqual(type.aggregationStyle, .cumulative, metric.identifier)
        }
    }

    func testStepCountIsReportedFromHealthKit() {
        // HealthKit's consolidated step count also sees an Apple Watch, unlike `PedometerSensor`.
        XCTAssertEqual(HealthKitMetric.metric(uniqueID: "health_steps"), HealthKitMetric.steps)
        XCTAssertTrue(HealthKitMetric.all.contains { $0.identifier == "HKQuantityTypeIdentifierStepCount" })
    }

    func testShippedMetricsKeepTheirIdentityStable() {
        XCTAssertEqual(HealthKitMetric.restingHeartRate.uniqueID, "health_resting_heart_rate")
        XCTAssertEqual(HealthKitMetric.restingHeartRate.name, "Resting Heart Rate")
        XCTAssertEqual(HealthKitMetric.restingHeartRate.icon, "mdi:heart-pulse")
        XCTAssertEqual(HealthKitMetric.restingHeartRate.unit, "bpm")

        XCTAssertEqual(HealthKitMetric.steps.uniqueID, "health_steps")
        XCTAssertEqual(HealthKitMetric.steps.name, "Health Steps")
        XCTAssertEqual(HealthKitMetric.steps.icon, "mdi:walk")
        XCTAssertEqual(HealthKitMetric.steps.unit, "steps")
    }

    func testStateAppliesScaleAndRounding() throws {
        XCTAssertEqual(HealthKitMetric.restingHeartRate.state(for: 62.4) as? Double, 62.4)

        let energy = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_active_energy_burned"))
        XCTAssertEqual(energy.state(for: 1234.4) as? Int, 1234)

        let bodyFat = try XCTUnwrap(HealthKitMetric.metric(uniqueID: "health_body_fat_percentage"))
        XCTAssertEqual(bodyFat.state(for: 0.1234) as? Double, 12.3)
    }
}
