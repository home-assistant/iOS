import Foundation
@testable import Shared
import Testing

struct WatchDeviceRegistrationTests {
    @Test func roundTripsThroughJSON() throws {
        let registration = WatchDeviceRegistration(
            webhookID: "hook",
            webhookSecret: "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff",
            cloudhookURL: URL(string: "https://hooks.nabu.casa/hook"),
            registeredAt: Date(timeIntervalSince1970: 1_700_000_000),
            registeredSensorEnablement: ["battery_level": true, "battery_state": false]
        )

        let data = try JSONEncoder().encode(registration)
        let decoded = try JSONDecoder().decode(WatchDeviceRegistration.self, from: data)

        #expect(decoded == registration)
        #expect(decoded.webhookPath == "api/webhook/hook")
    }

    @Test func derivesTheSecretKeyLikeConnectionInfo() {
        let secret = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        let registration = WatchDeviceRegistration(
            webhookID: "hook",
            webhookSecret: secret,
            cloudhookURL: nil,
            registeredAt: Date()
        )
        let version = Version(major: 2026, minor: 1, patch: 0, prerelease: nil, build: nil)

        let connection = ConnectionInfo(
            externalURL: URL(string: "https://example.com"),
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "hook",
            webhookSecret: secret,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        #expect(registration.webhookSecretBytes(version: version) == connection.webhookSecretBytes(version: version))
        #expect(registration.webhookSecretBytes(version: version)?.count == 32)
    }

    @Test func noSecretMeansNoKey() {
        let registration = WatchDeviceRegistration(
            webhookID: "hook",
            webhookSecret: nil,
            cloudhookURL: nil,
            registeredAt: Date()
        )

        #expect(registration.webhookSecretBytes(
            version: Version(major: 2026, minor: 1, patch: 0, prerelease: nil, build: nil)
        ) == nil)
    }
}
