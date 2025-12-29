@testable import Shared
import Version
import XCTest

class ConnectionInfoTests: XCTestCase {
    func testInternalOnlyURL() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: url,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testInternalOnlyURLWithoutSSIDWithAlwaysFallbackEnabled() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: url,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.internalSSIDs = []
        Current.connectivity.currentWiFiSSID = { "" }

        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testInternalOnlyURLWithoutSSIDWithLocalAccessSecurityLevelMostSecure() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: url,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        info.internalSSIDs = []
        Current.connectivity.currentWiFiSSID = { "" }

        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)
    }

    func testInternalURLWithUndefinedSSID() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: url,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        Current.connectivity.currentWiFiSSID = { nil }

        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)
    }

    func testRemoteOnlyURL() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: url,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.useCloud = true
        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testRemoteOnlyURLWithUseCloudOffAndNoSSIDNeitherInternalURLWithLocalAccessSecurityLevelMostSecure() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: url,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        info.useCloud = false
        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)
    }

    func testExternalOnlyURL() async {
        let url = URL(string: "http://example.com:8123")
        var info = ConnectionInfo(
            externalURL: url,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testInternalExternalURL() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(await info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testExternalRemoteURL() async {
        let externalURL = URL(string: "http://external.example.com:8123")
        let remoteURL = URL(string: "http://remote.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: remoteURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(await info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        XCTAssertEqual(await info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(await info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))
    }

    func testInternalRemoteURL() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let remoteURL = URL(string: "http://remote.example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: remoteURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.useCloud = true

        XCTAssertEqual(await info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(await info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testInternalRemoteURLWithoutSSIDDefinedWithMostSecureLocalAccessLevel() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let remoteURL = URL(string: "http://remote.example.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: remoteURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)
    }

    func testInternalExternalRemoteURL() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        let remoteURL = URL(string: "http://remote.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: remoteURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(await info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        XCTAssertEqual(await info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(await info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalHardwareAddresses = nil
    }

    func testOverrideURL() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        let remoteURL = URL(string: "http://remote.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: remoteURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        // valid override states

        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(await info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(await info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .external
        XCTAssertEqual(await info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .internal
        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        // invalid override states

        info.set(address: nil, for: .remoteUI)
        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(await info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(await info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        // No SSID defined for internal URL
        info.set(address: nil, for: .external)
        info.overrideActiveURLType = .external
        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)

        // With SSID defined for internal URL
        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(await info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testNoFallbackURL() async {
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: nil,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(await info.activeURL(), nil)
        XCTAssertEqual(await info.webhookURL(), nil)
        XCTAssertEqual(await info.activeAPIURL(), nil)
    }

    func testWebhookURL() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        let cloudhookURL = URL(string: "http://cloudhook.example.com")

        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: nil,
            cloudhookURL: cloudhookURL,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: ["unit_tests"],
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        Current.connectivity.currentWiFiSSID = { nil }

        XCTAssertEqual(await info.webhookURL(), cloudhookURL)

        info.set(address: internalURL, for: .internal)
        XCTAssertEqual(await info.webhookURL(), cloudhookURL)

        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(await info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))

        Current.connectivity.currentWiFiSSID = { nil }
        XCTAssertEqual(await info.webhookURL(), cloudhookURL)
    }

    func testWebhookSecret() {
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: URL(string: "http://internal.example.com/"),
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        let oldVersion = Version(major: 2022, minor: 2)
        let newVersion = Version(major: 2022, minor: 3)

        XCTAssertNil(info.webhookSecretBytes(version: oldVersion))
        XCTAssertNil(info.webhookSecretBytes(version: newVersion))

        info.webhookSecret = String(repeating: "0", count: 33)
        XCTAssertNil(info.webhookSecretBytes(version: oldVersion))
        XCTAssertNil(info.webhookSecretBytes(version: newVersion))
        info.webhookSecret = String(repeating: "0", count: 31)
        XCTAssertNil(info.webhookSecretBytes(version: oldVersion))
        XCTAssertNil(info.webhookSecretBytes(version: newVersion))

        info.webhookSecret = "abcdef0fedcba0abcdef0fedcba0abcdef0abcdef0fedcba0abcdef0fedcba"
        XCTAssertEqual(
            info.webhookSecretBytes(version: oldVersion),
            // incorrectly using ascii/utf8 of the first 32 characters
            [
                97,
                98,
                99,
                100,
                101,
                102,
                48,
                102,
                101,
                100,
                99,
                98,
                97,
                48,
                97,
                98,
                99,
                100,
                101,
                102,
                48,
                102,
                101,
                100,
                99,
                98,
                97,
                48,
                97,
                98,
                99,
                100,
            ]
        )
        XCTAssertEqual(
            info.webhookSecretBytes(version: newVersion),
            // using the full hex representation
            [
                0xAB,
                0xCD,
                0xEF,
                0x0F,
                0xED,
                0xCB,
                0xA0,
                0xAB,
                0xCD,
                0xEF,
                0x0F,
                0xED,
                0xCB,
                0xA0,
                0xAB,
                0xCD,
                0xEF,
                0x0A,
                0xBC,
                0xDE,
                0xF0,
                0xFE,
                0xDC,
                0xBA,
                0x0A,
                0xBC,
                0xDE,
                0xF0,
                0xFE,
                0xDC,
                0xBA,
            ]
        )
    }

    func testInvitationURLForCloud() {
        let internalURL = URL(string: "http://internal.com:8123")
        let remoteURL = URL(string: "http://remote.com:8123")
        let cloudURL = URL(string: "http://cloud.com:8123")
        let useCloud = true
        var info = ConnectionInfo(
            externalURL: remoteURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: cloudURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.useCloud = useCloud
        XCTAssertEqual(info.invitationURL(), cloudURL)
    }

    func testInvitationURLForRemoteWithCloudOff() {
        let internalURL = URL(string: "http://internal.com:8123")
        let remoteURL = URL(string: "http://remote.com:8123")
        let cloudURL = URL(string: "http://cloud.com:8123")
        let useCloud = false
        var info = ConnectionInfo(
            externalURL: remoteURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: cloudURL,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        info.useCloud = useCloud
        XCTAssertEqual(info.invitationURL(), remoteURL)
    }

    func testInvitationURLForRemoteWithoutCloud() {
        let internalURL = URL(string: "http://internal.com:8123")
        let remoteURL = URL(string: "http://remote.com:8123")
        let info = ConnectionInfo(
            externalURL: remoteURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(info.invitationURL(), remoteURL)
    }

    func testInvitationURLForInternal() {
        let internalURL = URL(string: "http://internal.com:8123")
        let info = ConnectionInfo(
            externalURL: nil,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertEqual(info.invitationURL(), internalURL)
    }

    func testFallbackToInternalURLWhenItIsHTTPS() async {
        let internalURL = URL(string: "https://internal.com:8123")
        var info = ConnectionInfo(
            externalURL: nil,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .mostSecure
        )

        XCTAssertEqual(await info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
    }
}
