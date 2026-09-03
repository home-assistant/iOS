import Foundation
@testable import Shared
import Testing

// Serialized: several tests swap `Current` dependencies.
@Suite(.serialized)
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

    @Test func deviceNameIsCompanionDeviceNamePlusWatchName() {
        #expect(WatchDeviceIdentity.deviceName(
            companionDeviceName: "Bruno's iPhone",
            watchName: "Apple Watch"
        ) == "Bruno's iPhone Apple Watch")
        #expect(WatchDeviceIdentity.deviceName(
            companionDeviceName: "  Kitchen Phone \n",
            watchName: "Apple Watch"
        ) == "Kitchen Phone Apple Watch")
    }

    @Test func deviceNameStandsAloneWithoutACompanionName() {
        #expect(WatchDeviceIdentity.deviceName(companionDeviceName: nil, watchName: "Apple Watch") == "Apple Watch")
        #expect(WatchDeviceIdentity.deviceName(companionDeviceName: "", watchName: "Apple Watch") == "Apple Watch")
        #expect(WatchDeviceIdentity.deviceName(companionDeviceName: "   ", watchName: "Apple Watch") == "Apple Watch")
    }

    @Test func deviceNameForAServerReadsThePhonesStampedName() {
        let deviceName = Current.device.deviceName
        defer { Current.device.deviceName = deviceName }
        Current.device.deviceName = { "Apple Watch" }

        let stamped = Server.fake { $0.setSetting(value: "Bruno's iPhone", for: .companionDeviceName) }
        #expect(WatchDeviceIdentity.deviceName(for: stamped) == "Bruno's iPhone Apple Watch")

        let unstamped = Server.fake()
        #expect(WatchDeviceIdentity.deviceName(for: unstamped) == "Apple Watch")
    }

    @Test func updateRegistrationBodyCarriesWhatHomeAssistantRequires() {
        let body = WatchDeviceRegistrar.updateRegistrationBody(identity: identity)

        #expect(body["device_name"] as? String == "Bruno's Apple Watch")
        #expect(body["app_version"] as? String == "2026.1 (1)")
        #expect(body["manufacturer"] as? String == "Apple")
        #expect(body["model"] as? String == "Watch7,1")
        #expect(body["os_version"] as? String == "26.0")
        #expect((body["app_data"] as? [String: Any])?.isEmpty == true)
        #expect(body.count == 6)
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
            identity: identity,
            registeredAt: registeredAt
        )

        #expect(registration.webhookID == "abc123")
        #expect(registration.webhookSecret == "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff")
        #expect(registration.cloudhookURL == URL(string: "https://hooks.nabu.casa/abc"))
        #expect(registration.registeredAt == registeredAt)
        #expect(registration.registeredSensorEnablement.isEmpty)
        #expect(registration.deviceName == "Bruno's Apple Watch")
    }

    @Test func parsesRegistrationResponseWithoutCloudOrSecret() throws {
        let registration = try WatchDeviceRegistrar.registration(
            from: ["webhook_id": "plain"] as [String: Any],
            identity: identity,
            registeredAt: Date()
        )

        #expect(registration.webhookID == "plain")
        #expect(registration.webhookSecret == nil)
        #expect(registration.cloudhookURL == nil)
    }

    @Test func registerStoresWhatTheServerAnswered() async throws {
        let store = FakeWatchDeviceRegistrationStore()
        Current.watchDeviceRegistrations = store
        let date = Current.date
        defer { Current.date = date }
        Current.date = { Date(timeIntervalSince1970: 1_700_000_000) }
        let server = Server.fake()
        let capture = BodyCapture()

        let registration = try await WatchDeviceRegistrar.register(
            server: server,
            identity: identity,
            timeout: 5,
            send: { _, body, timeout in
                capture.body = body
                capture.timeout = timeout
                return ["webhook_id": "new-hook", "secret": "0011", "cloudhook_url": "https://hooks.nabu.casa/new"]
            }
        )

        #expect(registration.webhookID == "new-hook")
        #expect(registration.webhookSecret == "0011")
        #expect(registration.cloudhookURL == URL(string: "https://hooks.nabu.casa/new"))
        #expect(registration.registeredAt == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(store.registration(for: server.identifier) == registration)
        #expect(registration.deviceName == "Bruno's Apple Watch")
        #expect(capture.body?["app_name"] as? String == "Home Assistant Watch")
        #expect(capture.timeout == 5)
    }

    @Test func registerNamesTheWatchAfterThePhoneByDefault() async throws {
        Current.watchDeviceRegistrations = FakeWatchDeviceRegistrationStore()
        let deviceName = Current.device.deviceName
        defer { Current.device.deviceName = deviceName }
        Current.device.deviceName = { "Apple Watch" }
        let server = Server.fake { $0.setSetting(value: "Bruno's iPhone", for: .companionDeviceName) }
        let capture = BodyCapture()

        let registration = try await WatchDeviceRegistrar.register(
            server: server,
            send: { _, body, _ in
                capture.body = body
                return ["webhook_id": "new-hook"]
            }
        )

        #expect(capture.body?["device_name"] as? String == "Bruno's iPhone Apple Watch")
        #expect(registration.deviceName == "Bruno's iPhone Apple Watch")
    }

    @Test func registerReportsAMissingMobileAppIntegration() async {
        Current.watchDeviceRegistrations = FakeWatchDeviceRegistrationStore()

        await #expect(throws: HomeAssistantAPI.APIError.mobileAppComponentNotLoaded) {
            try await WatchDeviceRegistrar.register(server: Server.fake(), identity: identity, send: { _, _, _ in
                throw HomeAssistantRESTError.unacceptableStatus(code: 404, body: nil)
            })
        }
    }

    @Test func registerPassesOtherTransportErrorsThrough() async {
        Current.watchDeviceRegistrations = FakeWatchDeviceRegistrationStore()

        await #expect(throws: HomeAssistantRESTError.unacceptableStatus(code: 401, body: nil)) {
            try await WatchDeviceRegistrar.register(server: Server.fake(), identity: identity, send: { _, _, _ in
                throw HomeAssistantRESTError.unacceptableStatus(code: 401, body: nil)
            })
        }
    }

    @Test func registerFailsWhenTheRegistrationCannotBeKept() async {
        let store = FakeWatchDeviceRegistrationStore()
        store.writeError = CocoaError(.fileWriteUnknown)
        Current.watchDeviceRegistrations = store

        do {
            _ = try await WatchDeviceRegistrar.register(server: Server.fake(), identity: identity, send: { _, _, _ in
                ["webhook_id": "new-hook"]
            })
            Issue.record("expected the registration to fail")
        } catch let WatchDeviceRegistrar.RegistrationError.persistenceFailed(reason) {
            #expect(!reason.isEmpty)
        } catch {
            Issue.record("unexpected error \(error)")
        }
        #expect(store.all.isEmpty)
    }

    @Test func errorsDescribeThemselves() {
        #expect(WatchDeviceRegistrar.RegistrationError.unmappableResponse.errorDescription?.isEmpty == false)
        let persistence = WatchDeviceRegistrar.RegistrationError.persistenceFailed("no room")
        #expect(persistence.errorDescription?.contains("no room") == true)
    }

    @Test func currentIdentityDescribesThisDevice() {
        let deviceName = Current.device.deviceName
        let systemModel = Current.device.systemModel
        let systemName = Current.device.systemName
        let systemVersion = Current.device.systemVersion
        let identifierForVendor = Current.device.identifierForVendor
        defer {
            Current.device.deviceName = deviceName
            Current.device.systemModel = systemModel
            Current.device.systemName = systemName
            Current.device.systemVersion = systemVersion
            Current.device.identifierForVendor = identifierForVendor
        }
        Current.device.deviceName = { "Apple Watch" }
        Current.device.systemModel = { "Watch7,1" }
        Current.device.systemName = { "watchOS" }
        Current.device.systemVersion = { "26.0" }
        Current.device.identifierForVendor = { "vendor-id" }
        let server = Server.fake { $0.setSetting(value: "Bruno's iPhone", for: .companionDeviceName) }

        let identity = WatchDeviceIdentity.current(for: server)

        #expect(identity.appName.hasSuffix(" Watch"))
        #expect(identity.appVersion == HomeAssistantAPI.clientVersionDescription)
        #expect(identity.deviceName == "Bruno's iPhone Apple Watch")
        #expect(identity.deviceID.hasSuffix("vendor-id"))
        #expect(identity.model == "Watch7,1")
        #expect(identity.osName == "watchOS")
        #expect(identity.osVersion == "26.0")
        #expect(!identity.appID.isEmpty)
    }

    @Test func rejectsResponseWithoutWebhookID() {
        #expect(throws: WatchDeviceRegistrar.RegistrationError.unmappableResponse) {
            try WatchDeviceRegistrar.registration(
                from: ["secret": "x"] as [String: Any],
                identity: identity,
                registeredAt: Date()
            )
        }
        #expect(throws: WatchDeviceRegistrar.RegistrationError.unmappableResponse) {
            try WatchDeviceRegistrar.registration(from: "not a dictionary", identity: identity, registeredAt: Date())
        }
    }
}

/// Holds what a fake `send` saw, across the async hop the registrar makes.
private final class BodyCapture: @unchecked Sendable {
    var body: [String: Any]?
    var timeout: TimeInterval?
}
