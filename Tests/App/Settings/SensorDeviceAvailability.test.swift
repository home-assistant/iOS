@testable import HomeAssistant
@testable import Shared
import Testing

struct SensorDeviceAvailabilityTests {
    @Test(arguments: [
        WebhookSensorId.hingeAngle.rawValue,
        WebhookSensorId.hingeStatus.rawValue,
        WebhookSensorId.devicePose.rawValue,
    ])
    func hingeSensorsNeedAHinge(uniqueID: String) {
        #expect(SensorDeviceAvailability.isAvailable(sensorUniqueID: uniqueID, deviceHasHinge: true))
        #expect(!SensorDeviceAvailability.isAvailable(sensorUniqueID: uniqueID, deviceHasHinge: false))
    }

    @Test func otherSensorsAreAvailableEverywhere() {
        #expect(SensorDeviceAvailability.isAvailable(
            sensorUniqueID: WebhookSensorId.activity.rawValue,
            deviceHasHinge: false
        ))
        #expect(SensorDeviceAvailability.isAvailable(sensorUniqueID: nil, deviceHasHinge: false))
    }

    /// The rows are the providers' own unread sensors, so they carry the names Home Assistant would
    /// know them by.
    @Test func aDeviceWithoutAHingeListsEveryHingeSensorAsUnavailable() {
        let sensors = SensorDeviceAvailability.unavailableSensors(deviceHasHinge: false)

        #expect(sensors.map(\.UniqueID) == [
            WebhookSensorId.hingeAngle.rawValue,
            WebhookSensorId.hingeStatus.rawValue,
            WebhookSensorId.devicePose.rawValue,
        ])
        #expect(sensors.map(\.Name) == ["Hinge Angle", "Hinge Status", "Pose"])
    }

    @Test func aDeviceWithAHingeListsNothingAsUnavailable() {
        #expect(SensorDeviceAvailability.unavailableSensors(deviceHasHinge: true).isEmpty)
    }
}
