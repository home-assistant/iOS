import Foundation
@testable import Shared
import Testing

struct WatchDeviceRegistrarTests {
    private let identity = WatchDeviceIdentity(
        appID: "io.robbie.HomeAssistant.watchkitapp",
        appName: WatchDeviceIdentity.appName(companionAppName: "Home Assistant"),
        appVersion: "2026.1 (1)",
        deviceName: "Bruno's Apple Watch",
        deviceID: "watch-device-id",
        model: "Watch7,1",
        osName: "watchOS",
        osVersion: "26.0"
    )

    private let modern = Version(major: 2026, minor: 1, patch: 0, prerelease: nil, build: nil)

    @Test func appNameIsCompanionAppNamePlusWatch() {
        #expect(WatchDeviceIdentity.appName(companionAppName: "Home Assistant") == "Home Assistant Watch")
        #expect(WatchDeviceIdentity.appName(companionAppName: "Home Assistant Dev") == "Home Assistant Dev Watch")
    }

    @Test func registrationBodyDescribesTheWatch() {
        let body = WatchDeviceRegistrar.registrationBody(identity: identity, serverVersion: modern)

        #expect(body["app_id"] as? String == "io.robbie.HomeAssistant.watchkitapp")
        #expect(body["app_name"] as? String == "Home Assistant Watch")
        #expect(body["app_version"] as? String == "2026.1 (1)")
        #expect(body["device_name"] as? String == "Bruno's Apple Watch")
        #expect(body["device_id"] as? String == "watch-device-id")
        #expect(body["manufacturer"] as? String == "Apple")
        #expect(body["model"] as? String == "Watch7,1")
        #expect(body["os_name"] as? String == "watchOS")
        #expect(body["os_version"] as? String == "26.0")
        #expect(body["supports_encryption"] as? Bool == true)
        #expect((body["app_data"] as? [String: Any])?.isEmpty == true)
    }

    @Test func registrationBodyOmitsDeviceIDForServersThatPredateIt() {
        let old = Version(major: 0, minor: 100, patch: 0, prerelease: nil, build: nil)
        let body = WatchDeviceRegistrar.registrationBody(identity: identity, serverVersion: old)

        #expect(body["device_id"] == nil)
        #expect(body["device_name"] as? String == "Bruno's Apple Watch")
    }

    @Test func parsesRegistrationResponse() throws {
        let registeredAt = Date(timeIntervalSince1970: 1_700_000_000)
        let registration = try WatchDeviceRegistrar.registration(
            from: [
                "webhook_id": "abc123",
                "secret": "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
                "cloudhook_url": "https://hooks.nabu.casa/abc",
                "remote_ui_url": "https://example.ui.nabu.casa",
            ] as [String: Any],
            registeredAt: registeredAt
        )

        #expect(registration.webhookID == "abc123")
        #expect(registration.webhookSecret == "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff")
        #expect(registration.cloudhookURL == URL(string: "https://hooks.nabu.casa/abc"))
        #expect(registration.registeredAt == registeredAt)
        #expect(registration.registeredSensorEnablement.isEmpty)
    }

    @Test func parsesRegistrationResponseWithoutCloudOrSecret() throws {
        let registration = try WatchDeviceRegistrar.registration(
            from: ["webhook_id": "plain"] as [String: Any],
            registeredAt: Date()
        )

        #expect(registration.webhookID == "plain")
        #expect(registration.webhookSecret == nil)
        #expect(registration.cloudhookURL == nil)
    }

    @Test func rejectsResponseWithoutWebhookID() {
        #expect(throws: WatchDeviceRegistrar.RegistrationError.unmappableResponse) {
            try WatchDeviceRegistrar.registration(from: ["secret": "x"] as [String: Any], registeredAt: Date())
        }
        #expect(throws: WatchDeviceRegistrar.RegistrationError.unmappableResponse) {
            try WatchDeviceRegistrar.registration(from: "not a dictionary", registeredAt: Date())
        }
    }
}
