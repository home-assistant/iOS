import Foundation

/// The sensor unique IDs the app knows about at compile time.
///
/// Enablement is an allowlist and every sensor is opt-in, so this is not a list of what reports.
/// It exists to tell the IDs the app can name apart from the ones that only exist at runtime — one
/// per battery, SIM or audio device — which `SensorEnablementStore` picks up from the first batch
/// of sensors the app actually produces.
public enum SensorRegistry {
    public static let staticSensorIDs: Set<String> =
        includingRuntimeFamilies(of: Set(WebhookSensorId.allCases.map(\.rawValue)))

    /// The IDs an install that predates the allowlist could have been reporting, frozen at the
    /// release that introduced it.
    ///
    /// The denylist-to-allowlist migration seeds from this rather than from `staticSensorIDs`,
    /// which is what keeps a sensor added later from being read as one that install had chosen: its
    /// denylist cannot mention a sensor that didn't exist yet, and silence there means "enabled".
    /// Nothing is added to this set — a new sensor is opt-in, so its absence here is the point.
    public static let legacyEraSensorIDs: Set<String> =
        includingRuntimeFamilies(of: legacyEraWebhookSensorIDs)

    /// Sensors that must never switch on without the user asking for them, so the migration leaves
    /// them off unless the old denylist proves the user had turned one on. The camera ones turn the
    /// camera on and surface its permission prompt; Apple Health reads someone's health data, which
    /// shouldn't start happening because they installed an update.
    public static let optInSensorIDs: Set<String> = {
        var ids: Set<String> = [
            WebhookSensorId.cameraMotion.rawValue,
            WebhookSensorId.cameraStream.rawValue,
        ]
        #if os(iOS) && !targetEnvironment(macCatalyst)
        ids.formUnion(HealthKitMetric.all.map(\.uniqueID))
        #endif
        return ids
    }()

    /// The `WebhookSensorId` raw values as they stood when the allowlist shipped. Frozen history:
    /// a new sensor belongs in the enum alone.
    private static let legacyEraWebhookSensorIDs: Set<String> = [
        "iphone-audio-output",
        "activity",
        "connectivity_ssid",
        "connectivity_bssid",
        "connectivity_connection_type",
        "geocoded_location",
        "last_update_trigger",
        "storage",
        "camera",
        "microphone",
        "audio_output",
        "active",
        "displays_count",
        "primary_display_name",
        "primary_display_id",
        "frontmost_app",
        "watch-battery",
        "watch-battery-state",
        "app-version",
        "location-permission",
        "focus",
        "pressure",
        "kioskMode",
        "kioskBrightness",
        "kioskVolume",
        "kioskScreensaver",
        "cameraMotion",
        "cameraStream",
    ]

    /// Adds the IDs the app derives from a set of sensors rather than naming directly, all of which
    /// predate the allowlist and so belong to both eras.
    private static func includingRuntimeFamilies(of webhookSensorIDs: Set<String>) -> Set<String> {
        var ids = webhookSensorIDs

        // InputOutputDeviceSensor derives an "in use" and an "active" sensor from each of these.
        for base in [WebhookSensorId.camera, .microphone, .audioOutput].map(\.rawValue)
            where webhookSensorIDs.contains(base) {
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
    }
}
