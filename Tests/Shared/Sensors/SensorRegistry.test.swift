import Foundation
@testable import Shared
import XCTest

class SensorRegistryTests: XCTestCase {
    func testStaticSensorIDsCoverEveryWebhookSensorId() {
        for sensorId in WebhookSensorId.allCases {
            XCTAssertTrue(
                SensorRegistry.staticSensorIDs.contains(sensorId.rawValue),
                "\(sensorId.rawValue) is missing from the registry"
            )
        }
    }

    func testStaticSensorIDsCoverTheSensorsDerivedFromOtherIDs() {
        for base in [WebhookSensorId.camera, .microphone, .audioOutput].map(\.rawValue) {
            XCTAssertTrue(SensorRegistry.staticSensorIDs.contains("\(base)_in_use"))
            XCTAssertTrue(SensorRegistry.staticSensorIDs.contains("active_\(base)"))
        }
    }

    func testStaticSensorIDsCoverSensorsOutsideWebhookSensorId() {
        XCTAssertTrue(SensorRegistry.staticSensorIDs.contains("battery_level"))
        XCTAssertTrue(SensorRegistry.staticSensorIDs.contains("battery_state"))

        for uniqueID in PedometerSensor.allSensorIDs {
            XCTAssertTrue(SensorRegistry.staticSensorIDs.contains(uniqueID))
        }
        for metric in HealthKitMetric.all {
            XCTAssertTrue(SensorRegistry.staticSensorIDs.contains(metric.uniqueID))
        }
    }

    func testOptInSensorsAreTheCameraAndAppleHealthOnes() {
        XCTAssertTrue(SensorRegistry.optInSensorIDs.contains(WebhookSensorId.cameraMotion.rawValue))
        XCTAssertTrue(SensorRegistry.optInSensorIDs.contains(WebhookSensorId.cameraStream.rawValue))
        for metric in HealthKitMetric.all {
            XCTAssertTrue(SensorRegistry.optInSensorIDs.contains(metric.uniqueID), metric.uniqueID)
        }
        XCTAssertEqual(SensorRegistry.optInSensorIDs.count, HealthKitMetric.all.count + 2)
    }

    // MARK: - The frozen legacy-era set

    /// The migration seeds the allowlist from this, so anything missing is a sensor an upgrading
    /// user would silently lose.
    func testLegacyEraSensorIDsCoverTheSensorsThatPredateTheAllowlist() {
        for uniqueID in [
            WebhookSensorId.activity.rawValue,
            WebhookSensorId.storage.rawValue,
            WebhookSensorId.focus.rawValue,
            WebhookSensorId.pressure.rawValue,
            WebhookSensorId.cameraMotion.rawValue,
            WebhookSensorId.locationPermission.rawValue,
            "battery_level",
            "battery_state",
            "camera_in_use",
            "active_camera",
        ] + PedometerSensor.allSensorIDs {
            XCTAssertTrue(SensorRegistry.legacyEraSensorIDs.contains(uniqueID), uniqueID)
        }
        for metric in HealthKitMetric.all {
            XCTAssertTrue(SensorRegistry.legacyEraSensorIDs.contains(metric.uniqueID), metric.uniqueID)
        }
    }

    /// What keeps a new sensor from being read as one an upgrading install had chosen. Nothing is
    /// added to the frozen set, so this holds for every sensor added from here on.
    func testLegacyEraSensorIDsExcludeSensorsAddedAfterTheAllowlist() {
        XCTAssertFalse(SensorRegistry.legacyEraSensorIDs.contains(WebhookSensorId.focusName.rawValue))
        XCTAssertTrue(SensorRegistry.staticSensorIDs.contains(WebhookSensorId.focusName.rawValue))
    }

    func testLegacyEraSensorIDsAreAllStillKnown() {
        XCTAssertTrue(SensorRegistry.legacyEraSensorIDs.isSubset(of: SensorRegistry.staticSensorIDs))
    }
}
