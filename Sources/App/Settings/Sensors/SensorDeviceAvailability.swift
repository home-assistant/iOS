import Foundation
import Shared

/// Which sensors need hardware only some devices have, and whether this device has it.
///
/// The hinge sensors can only ever read something on a device that folds. Anywhere else the sensors
/// list keeps them out of reach in a section of their own at the bottom, with nothing to switch on,
/// rather than offering a sensor that could never report anything.
enum SensorDeviceAvailability {
    /// Whether the sensor with this unique ID can be switched on, given whether this device has a
    /// hinge. Every sensor that does not depend on one can.
    static func isAvailable(sensorUniqueID: String?, deviceHasHinge: Bool) -> Bool {
        guard let sensorUniqueID, hingeSensorIDs.contains(sensorUniqueID) else { return true }
        return deviceHasHinge
    }

    /// The rows to list as unavailable on this device, or none when it has a hinge.
    ///
    /// Built here rather than taken from the providers, which stop listing these sensors once the
    /// device turns out to have no hinge: whatever a provider lists is also registered with every
    /// server, and these have no business there from a device that can never report them.
    static func unavailableSensors(deviceHasHinge: Bool) -> [WebhookSensor] {
        guard !deviceHasHinge else { return [] }
        return HingeSensor.unreadSensors() + [DevicePoseSensor.unreadSensor()]
    }

    private static let hingeSensorIDs: Set<String> = [
        WebhookSensorId.hingeAngle.rawValue,
        WebhookSensorId.hingeStatus.rawValue,
        WebhookSensorId.devicePose.rawValue,
    ]
}
