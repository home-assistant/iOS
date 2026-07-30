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
        for metric in HealthKitMetric.all {
            XCTAssertTrue(
                metric.identifier.hasPrefix("HKQuantityTypeIdentifier"),
                metric.identifier
            )
            XCTAssertTrue(seen.insert(metric.identifier).inserted, "duplicate \(metric.identifier)")

            guard isAvailableOnThisOS(metric) else { continue }
            XCTAssertNotNil(quantityType(for: metric), metric.identifier)
        }
    }

    func testUnitsAreCompatibleWithTheirQuantityType() {
        for metric in HealthKitMetric.all where isAvailableOnThisOS(metric) {
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
