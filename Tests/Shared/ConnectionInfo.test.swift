@testable import Shared
import Version
import XCTest

class ConnectionInfoTests: XCTestCase {
    func testInternalOnlyURL() {
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
            securityExceptions: .init()
        )

        Current.connectivity.currentWiFiSSID = { nil }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testRemoteOnlyURL() {
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
            securityExceptions: .init()
        )

        info.useCloud = false
        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.useCloud = true
        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testExternalOnlyURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), url?.appendingPathComponent("api"))
    }

    func testInternalExternalURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testExternalRemoteURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))
    }

    func testInternalRemoteURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testInternalExternalRemoteURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        info.internalHardwareAddresses = nil
    }

    func testOverrideURL() {
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
            securityExceptions: .init()
        )

        // valid override states

        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(info.webhookURL(), remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), remoteURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .external
        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .internal
        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))

        // invalid override states

        info.set(address: nil, for: .remoteUI)
        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(info.webhookURL(), externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), externalURL?.appendingPathComponent("api"))

        info.set(address: nil, for: .external)
        info.overrideActiveURLType = .external
        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), internalURL?.appendingPathComponent("api"))
    }

    func testFallbackURL() {
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
            securityExceptions: .init()
        )

        XCTAssertEqual(info.activeURL(), URL(string: "http://homeassistant.local:8123"))
        XCTAssertEqual(info.webhookURL(), URL(string: "http://homeassistant.local:8123/api/webhook/webhook_id1"))
        XCTAssertEqual(info.activeAPIURL(), URL(string: "http://homeassistant.local:8123/api"))
    }

    func testWebhookURL() {
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
            securityExceptions: .init()
        )

        Current.connectivity.currentWiFiSSID = { nil }

        XCTAssertEqual(info.webhookURL(), cloudhookURL)

        info.set(address: internalURL, for: .internal)
        XCTAssertEqual(info.webhookURL(), cloudhookURL)

        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.webhookURL(), internalURL?.appendingPathComponent("api/webhook/webhook_id1"))

        Current.connectivity.currentWiFiSSID = { nil }
        XCTAssertEqual(info.webhookURL(), cloudhookURL)
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
            securityExceptions: .init()
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
}
