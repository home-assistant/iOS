import Foundation

/// The sensor unique IDs the app knows about at compile time.
///
/// Enablement is stored as an allowlist, so migrating an install that predates it needs to know
/// every ID that used to be enabled by default. IDs that only exist at runtime — one per battery,
/// SIM or audio device — can't be listed here; `SensorEnablementStore` picks those up from the
/// first batch of sensors the app actually produces.
public enum SensorRegistry {
    public static let staticSensorIDs: Set<String> = {
        var ids = Set(WebhookSensorId.allCases.map(\.rawValue))

        // InputOutputDeviceSensor derives an "in use" and an "active" sensor from each of these.
        for base in [WebhookSensorId.camera, .microphone, .audioOutput].map(\.rawValue) {
            ids.insert("\(base)_in_use")
            ids.insert("active_\(base)")
        }

        // BatterySensor keys off each battery's own identifier and falls back to this on devices
        // that only report one battery.
        ids.formUnion(["battery_level", "battery_state"])

        ids.formUnion(PedometerSensor.allSensorIDs)

        #if os(iOS) && !targetEnvironment(macCatalyst)
        ids.formUnion(HealthKitMetric.all.map(\.uniqueID))
        #endif

        return ids
    }()

    /// Sensors that must never switch on without the user asking for them: both turn the camera on
    /// and surface its permission prompt.
    public static let optInSensorIDs: Set<String> = [
        WebhookSensorId.cameraMotion.rawValue,
        WebhookSensorId.cameraStream.rawValue,
    ]

    /// The sensors a first-time install starts with. Everything else stays off until the user
    /// enables it in settings.
    public static func isEnabledByDefaultOnFirstRun(uniqueID: String) -> Bool {
        if uniqueID.contains("battery") {
            return true
        }
        return [WebhookSensorId.appVersion, .locationPermission]
            .map(\.rawValue)
            .contains(uniqueID)
    }
}
