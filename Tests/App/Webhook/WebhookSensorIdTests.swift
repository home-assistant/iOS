@testable import Shared
import Testing

struct WebhookSensorIdTests {
    @Test func testWebhookSensorIdRawValues() async throws {
        assert(WebhookSensorId.iPhoneAudioOutput.rawValue == "iphone-audio-output")
        assert(WebhookSensorId.activity.rawValue == "activity")
        assert(WebhookSensorId.connectivitySSID.rawValue == "connectivity_ssid")
        assert(WebhookSensorId.connectivityBSID.rawValue == "connectivity_bssid")
        assert(WebhookSensorId.connectivityConnectionType.rawValue == "connectivity_connection_type")
        assert(WebhookSensorId.geocodedLocation.rawValue == "geocoded_location")
        assert(WebhookSensorId.lastUpdateTrigger.rawValue == "last_update_trigger")
        assert(WebhookSensorId.storage.rawValue == "storage")
        assert(WebhookSensorId.camera.rawValue == "camera")
        assert(WebhookSensorId.microphone.rawValue == "microphone")
        assert(WebhookSensorId.audioOutput.rawValue == "audio_output")
        assert(WebhookSensorId.active.rawValue == "active")
        assert(WebhookSensorId.displaysCount.rawValue == "displays_count")
        assert(WebhookSensorId.primaryDisplayName.rawValue == "primary_display_name")
        assert(WebhookSensorId.primaryDisplayId.rawValue == "primary_display_id")
        assert(WebhookSensorId.frontmostApp.rawValue == "frontmost_app")
        assert(WebhookSensorId.watchBattery.rawValue == "watch-battery")
        assert(WebhookSensorId.watchBatteryState.rawValue == "watch-battery-state")
        assert(WebhookSensorId.appVersion.rawValue == "app-version")
        assert(WebhookSensorId.locationPermission.rawValue == "location-permission")
        assert(
            WebhookSensorId.allCases.count == 20,
            "WebhookSensorId has different number of cases than defined in test, \(WebhookSensorId.allCases.count)"
        )
    }
}
