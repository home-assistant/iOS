import Foundation

public enum WebhookSensorId: String, CaseIterable {
    case iPhoneAudioOutput = "iphone-audio-output"
    case activity = "activity"
    case connectivitySSID = "connectivity_ssid"
    case connectivityBSID = "connectivity_bssid"
    case connectivityConnectionType = "connectivity_connection_type"
    case geocodedLocation = "geocoded_location"
    case lastUpdateTrigger = "last_update_trigger"
    case storage = "storage"
    case camera = "camera"
    case microphone = "microphone"
    case audioOutput = "audio_output"
    case active = "active"
    case displaysCount = "displays_count"
    case primaryDisplayName = "primary_display_name"
    case primaryDisplayId = "primary_display_id"
    case frontmostApp = "frontmost_app"
    /// No longer produced: the watch reports its battery itself, as a device of its own. Kept so the
    /// frozen legacy-era set (`SensorRegistry.legacyEraSensorIDs`) still names IDs the app knows.
    case watchBattery = "watch-battery"
    case watchBatteryState = "watch-battery-state"
    case appVersion = "app-version"
    case locationPermission = "location-permission"
    case focus
    case focusName = "focus_name"
    case pressure
    case kioskMode
    case kioskBrightness
    case kioskVolume
    case kioskScreensaver
    case cameraMotion
    case cameraStream
}
