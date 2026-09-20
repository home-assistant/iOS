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
             .active,
             .focus,
             .focusName,
             .locationPermission,
             .displaysCount,
             .primaryDisplayName,
             .primaryDisplayId,
             .watchBattery,
             .watchBatteryState,
             .kioskMode:
            return .diagnostic
        case .activity,
             .geocodedLocation,
             .pressure,
             .frontmostApp,
             .iPhoneAudioOutput,
             .camera,
             .microphone,
             .audioOutput,
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
