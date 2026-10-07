@testable import HomeAssistant
@testable import Shared
import Testing

struct SensorForegroundAvailabilityTests {
    /// The camera sensors produce nothing at all in the background: iOS stops the capture session.
    @Test func testCameraSensorsAreForegroundOnly() {
        #expect(SensorForegroundAvailability.isForegroundOnly(
            sensorUniqueID: WebhookSensorId.cameraMotion.rawValue
        ))
        #expect(SensorForegroundAvailability.isForegroundOnly(
            sensorUniqueID: WebhookSensorId.cameraStream.rawValue
        ))
    }

    /// The kiosk device-state sensors stay readable in the background but stop changing, which is
    /// just as misleading to read from Home Assistant.
    @Test func testKioskDeviceStateSensorsAreForegroundOnly() {
        for sensorID in [WebhookSensorId.kioskBrightness, .kioskVolume, .kioskScreensaver] {
            #expect(SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: sensorID.rawValue))
        }
    }

    /// Kiosk mode itself reads a stored setting, so it is as current in the background as anywhere.
    @Test func testKioskModeIsNotForegroundOnly() {
        #expect(SensorForegroundAvailability.isForegroundOnly(
            sensorUniqueID: WebhookSensorId.kioskMode.rawValue
        ) == false)
    }

    @Test func testSensorsThatReportInTheBackgroundAreNotMarked() {
        for sensorID in [
            WebhookSensorId.activity,
            .focus,
            .geocodedLocation,
            .pressure,
            .storage,
        ] {
            #expect(SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: sensorID.rawValue) == false)
        }
    }

    @Test func testUnknownAndMissingIDsAreNotMarked() {
        #expect(SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: nil) == false)
        #expect(SensorForegroundAvailability.isForegroundOnly(sensorUniqueID: "not-a-sensor") == false)
    }
}
