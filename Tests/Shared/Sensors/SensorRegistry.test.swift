import Foundation
@testable import Shared
import XCTest

class SensorRegistryTests: XCTestCase {
    /// The migration seeds the allowlist from this, so anything missing here is a sensor an
    /// upgrading user would silently lose.
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
        for metric in HealthKitSensor.Metric.allCases {
            XCTAssertTrue(SensorRegistry.staticSensorIDs.contains(metric.uniqueID))
        }
    }

    func testOptInSensorsAreTheCameraOnes() {
        XCTAssertEqual(SensorRegistry.optInSensorIDs, [
            WebhookSensorId.cameraMotion.rawValue,
            WebhookSensorId.cameraStream.rawValue,
        ])
    }

    func testOptInSensorsAreNeverOnByDefault() {
        for uniqueID in SensorRegistry.optInSensorIDs {
            XCTAssertFalse(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: uniqueID))
        }
    }

    func testFirstRunDefaultsMatchWhatOnboardingUsedToKeepEnabled() {
        for uniqueID in ["battery_level", "battery_state", "watch-battery", "watch-battery-state"] {
            XCTAssertTrue(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: uniqueID))
        }
        XCTAssertTrue(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: WebhookSensorId.appVersion.rawValue))
        XCTAssertTrue(
            SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: WebhookSensorId.locationPermission.rawValue)
        )

        XCTAssertFalse(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: WebhookSensorId.storage.rawValue))
        XCTAssertFalse(SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: WebhookSensorId.activity.rawValue))
        XCTAssertFalse(
            SensorRegistry.isEnabledByDefaultOnFirstRun(uniqueID: HealthKitSensor.Metric.steps.uniqueID)
        )
    }
}
