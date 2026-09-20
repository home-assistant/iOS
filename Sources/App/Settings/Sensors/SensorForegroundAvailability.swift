import Foundation
import Shared

/// Which sensors are only worth reading while the app is open on screen.
///
/// Either the sensor produces nothing at all once the app leaves the foreground, or the value it
/// last sent can no longer change, so what Home Assistant holds is whatever was true when the app
/// went away. The sensors list marks them, so a sensor that stops moving reads as a limitation of
/// the platform rather than a broken sensor.
enum SensorForegroundAvailability {
    /// Whether the sensor with this unique ID only reports while the app is in the foreground.
    static func isForegroundOnly(sensorUniqueID: String?) -> Bool {
        guard let sensorUniqueID else { return false }
        return foregroundOnlySensorIDs.contains(sensorUniqueID)
    }

    /// Sensors whose value the app cannot keep current in the background — not ones that merely
    /// update less often, which is true of nearly every sensor the app reports.
    private static let foregroundOnlySensorIDs: Set<String> = [
        // Both stand on a capture session, and iOS stops handing the app camera frames the moment
        // it is no longer the app on screen.
        WebhookSensorId.cameraMotion.rawValue,
        WebhookSensorId.cameraStream.rawValue,
        // The brightness notification and the `outputVolume` KVO that drive these are only
        // delivered to an active app, and the ambient audio session the volume sensor activates
        // does not survive backgrounding: the value stays readable but stops changing.
        WebhookSensorId.kioskBrightness.rawValue,
        WebhookSensorId.kioskVolume.rawValue,
        // The screensaver only exists while the app is the one drawing the screen.
        WebhookSensorId.kioskScreensaver.rawValue,
    ]
}
