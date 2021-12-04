@testable import Shared
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
            isLocalPushEnabled: false
        )

        Current.connectivity.currentWiFiSSID = { nil }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .internal)
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
            isLocalPushEnabled: false
        )

        info.useCloud = false
        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .remoteUI)

        info.useCloud = true
        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .remoteUI)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), url)
        XCTAssertEqual(info.activeURLType, .external)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)

        info.useCloud = true

        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)

        info.internalSSIDs = ["unit_tests"]
        Current.connectivity.currentWiFiSSID = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        Current.connectivity.currentNetworkHardwareAddress = { "unit_tests" }

        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)

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
            isLocalPushEnabled: false
        )

        // valid override states

        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(info.activeURL(), remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)

        info.overrideActiveURLType = .external
        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)

        info.overrideActiveURLType = .internal
        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)

        // invalid override states

        info.set(address: nil, for: .remoteUI)
        info.overrideActiveURLType = .remoteUI
        XCTAssertEqual(info.activeURL(), externalURL)
        XCTAssertEqual(info.activeURLType, .external)

        info.set(address: nil, for: .external)
        info.overrideActiveURLType = .external
        XCTAssertEqual(info.activeURL(), internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
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
            isLocalPushEnabled: false
        )

        XCTAssertEqual(info.activeURL(), URL(string: "http://homeassistant.local:8123"))
    }
}
