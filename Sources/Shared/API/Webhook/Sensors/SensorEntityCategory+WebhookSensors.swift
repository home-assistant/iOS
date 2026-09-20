import Foundation

public extension SensorEntityCategory {
    /// The category a sensor's entity is created with, by unique ID.
    ///
    /// Keyed by ID rather than set where each sensor is built, for the same reason
    /// `SensorPermission.required(forSensorUniqueID:)` is: a provider builds its sensor in several
    /// places — the real reading, the one that stands in while a permission is missing, the
    /// redacted one — and a category attached to only some of them would come and go with the
    /// state the sensor happens to be in.
    ///
    /// Classification follows the Android companion app wherever both report the same thing, so an
    /// iPhone and a phone look alike in Home Assistant. What the app can see about itself or the
    /// device it runs on is `diagnostic`; what it measures about the world around it, or about the
    /// person carrying it, is not.
    static func category(forSensorUniqueID uniqueID: String) -> SensorEntityCategory? {
        if let known = WebhookSensorId(rawValue: uniqueID) {
            return category(for: known)
        }
        return runtimeCategory(forSensorUniqueID: uniqueID)
    }

    /// Deliberately has no `default`: a sensor added to `WebhookSensorId` should not compile until
    /// someone has decided which side of the line it falls on.
    private static func category(for sensorID: WebhookSensorId) -> SensorEntityCategory? {
        switch sensorID {
        case .connectivitySSID, // Android: wifi_connection
             .connectivityBSID, // Android: wifi_bssid
             .connectivityConnectionType, // Android: network_type
             .storage, // Android: storage_sensor
             .lastUpdateTrigger, // Android: last_update
             .appVersion, // Android: current_version
             .active, // Android: is_interactive
             .focus, // Android: dnd_sensor
             .focusName, // the same Focus, by name
             // Whether the app may read location at all: its own state, and the thing to look at
             // when location stopped arriving.
             .locationPermission,
             // What a Mac has plugged into it. Android has no counterpart, but its equivalent
             // hardware inventory (android_os_version, android_os_security_patch) is diagnostic.
             .displaysCount,
             .primaryDisplayName,
             .primaryDisplayId,
             // Retired IDs, classified with the battery sensors that replaced them.
             .watchBattery,
             .watchBatteryState,
             // Whether kiosk mode is switched on, which is how the app is set up rather than
             // anything it has measured.
             .kioskMode:
            return .diagnostic
        case .activity, // Android: detected_activity
             .geocodedLocation, // Android: geocoded_location
             .pressure, // Android: pressure_sensor
             .frontmostApp, // Android: last_used_app
             .iPhoneAudioOutput, // Android: headphone_state
             // Never reported under these IDs: `InputOutputDeviceSensor` derives an "in use" and an
             // "active" sensor from each, left uncategorised with the rest of the runtime IDs.
             .camera,
             .microphone,
             .audioOutput,
             // The live state of a wall tablet, which is what a kiosk dashboard shows and what
             // automations act on. Android leaves screen_brightness uncategorised for the same
             // reason.
             .kioskBrightness,
             .kioskVolume,
             .kioskScreensaver,
             // Motion the device saw, and a stream someone asked it for.
             .cameraMotion,
             .cameraStream:
            return nil
        }
    }

    /// The sensors whose unique IDs only exist at runtime, one per battery or SIM.
    ///
    /// Everything else built that way — `InputOutputDeviceSensor`'s per-device sensors, the
    /// pedometer's and Apple Health's readings — is a measurement rather than a diagnostic, and so
    /// falls through uncategorised.
    private static func runtimeCategory(forSensorUniqueID uniqueID: String) -> SensorEntityCategory? {
        // Android: battery_level, battery_state.
        if uniqueID.hasSuffix(BatterySensor.levelIDSuffix) || uniqueID.hasSuffix(BatterySensor.stateIDSuffix) {
            return .diagnostic
        }

        // Android: sim_1, sim_2.
        if uniqueID.hasPrefix(ConnectivitySensor.simIDPrefix) {
            return .diagnostic
        }

        return nil
    }
}
