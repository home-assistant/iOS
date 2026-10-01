import Foundation

public extension SensorEntityCategory {
    static func category(forSensorUniqueID uniqueID: String) -> SensorEntityCategory? {
        if let known = WebhookSensorId(rawValue: uniqueID) {
            return category(for: known)
        }
        return runtimeCategory(forSensorUniqueID: uniqueID)
    }

    private static func category(for sensorID: WebhookSensorId) -> SensorEntityCategory? {
        switch sensorID {
        case .connectivitySSID,
             .connectivityBSID,
             .connectivityConnectionType,
             .storage,
             .lastUpdateTrigger,
             .appVersion,
             .locationPermission,
             .watchBattery,
             .watchBatteryState:
            return .diagnostic
        case .activity,
             .geocodedLocation,
             .pressure,
             .focus,
             .focusName,
             .active,
             .displaysCount,
             .primaryDisplayName,
             .primaryDisplayId,
             .frontmostApp,
             .iPhoneAudioOutput,
             .camera,
             .microphone,
             .audioOutput,
             .kioskMode,
             .kioskBrightness,
             .kioskVolume,
             .kioskScreensaver,
             .cameraMotion,
             .cameraStream:
            return nil
        }
    }

    private static func runtimeCategory(forSensorUniqueID uniqueID: String) -> SensorEntityCategory? {
        if uniqueID.hasSuffix(BatterySensor.levelIDSuffix) || uniqueID.hasSuffix(BatterySensor.stateIDSuffix) {
            return .diagnostic
        }

        if uniqueID.hasPrefix(ConnectivitySensor.simIDPrefix) {
            return .diagnostic
        }

        return nil
    }
}
