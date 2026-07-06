@testable import Shared
import XCTest

class ConnectionInfoTests: XCTestCase {
    override func setUp() {
        super.setUp()
        setNetworkState(NetworkState())
    }

    /// Makes the given network state what connectivity reports, both for fresh fetches and for the
    /// cached last-known state used by synchronous evaluation.
    private func setNetworkState(_ state: NetworkState) {
        Current.connectivity.currentNetworkState = { state }
        Current.connectivity.lastKnownNetworkState = { state }
        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { state }
        }
    }

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
        setNetworkState(NetworkState(ssid: "unit_tests"))

        let urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))
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
        setNetworkState(NetworkState(ssid: ""))

        let urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))
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
        setNetworkState(NetworkState(ssid: ""))

        let urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)
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

        setNetworkState(NetworkState(ssid: nil))

        let urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)
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
        let urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))
    }

    func testHasOnlyHTTPSURLOptions() {
        let info = ConnectionInfo(
            externalURL: URL(string: "https://external.example.com"),
            internalURL: URL(string: "https://internal.example.com"),
            cloudhookURL: nil,
            remoteUIURL: URL(string: "https://remote.example.com"),
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: nil,
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        XCTAssertTrue(info.hasOnlyHTTPSURLOptions)
        XCTAssertFalse(info.hasNonHTTPSURLOptions)
    }

    func testHasOnlyHTTPSURLOptionsFalseWhenHTTPURLExists() {
        let info = ConnectionInfo(
            externalURL: URL(string: "https://external.example.com"),
            internalURL: URL(string: "http://internal.example.com"),
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

        XCTAssertFalse(info.hasOnlyHTTPSURLOptions)
        XCTAssertTrue(info.hasNonHTTPSURLOptions)
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
        let urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)
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

        var urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        setNetworkState(NetworkState(ssid: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        setNetworkState(NetworkState(hardwareAddress: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, url)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, url?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, url?.appendingPathComponent("api"))
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

        var urls = await info.urls()
        XCTAssertEqual(urls.active, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, externalURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        setNetworkState(NetworkState(ssid: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        setNetworkState(NetworkState(hardwareAddress: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))
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

        var urls = await info.urls()
        XCTAssertEqual(urls.active, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        urls = await info.urls()
        XCTAssertEqual(urls.active, remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(urls.webhook, remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, remoteURL?.appendingPathComponent("api"))
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

        var urls = await info.urls()
        XCTAssertEqual(urls.active, remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(urls.webhook, remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        setNetworkState(NetworkState(ssid: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        setNetworkState(NetworkState(hardwareAddress: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))
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

        let urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)
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

        var urls = await info.urls()
        XCTAssertEqual(urls.active, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, externalURL?.appendingPathComponent("api"))

        info.useCloud = true

        urls = await info.urls()
        XCTAssertEqual(urls.active, remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(urls.webhook, remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, remoteURL?.appendingPathComponent("api"))

        info.internalSSIDs = ["unit_tests"]
        setNetworkState(NetworkState(ssid: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))

        info.internalSSIDs = nil
        info.internalHardwareAddresses = ["unit_tests"]
        setNetworkState(NetworkState(hardwareAddress: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))

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
        var urls = await info.urls()
        XCTAssertEqual(urls.active, remoteURL)
        XCTAssertEqual(info.activeURLType, .remoteUI)
        XCTAssertEqual(urls.webhook, remoteURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, remoteURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .external
        urls = await info.urls()
        XCTAssertEqual(urls.active, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, externalURL?.appendingPathComponent("api"))

        info.overrideActiveURLType = .internal
        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))

        // invalid override states

        info.set(address: nil, for: .remoteUI)
        info.overrideActiveURLType = .remoteUI
        urls = await info.urls()
        XCTAssertEqual(urls.active, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
        XCTAssertEqual(urls.webhook, externalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, externalURL?.appendingPathComponent("api"))

        // No SSID defined for internal URL
        info.set(address: nil, for: .external)
        info.overrideActiveURLType = .external
        urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(info.activeURLType, .none)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)

        // With SSID defined for internal URL
        info.internalSSIDs = ["unit_tests"]
        setNetworkState(NetworkState(ssid: "unit_tests"))

        urls = await info.urls()
        XCTAssertEqual(urls.active, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
        XCTAssertEqual(urls.webhook, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))
        XCTAssertEqual(urls.api, internalURL?.appendingPathComponent("api"))
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

        let urls = await info.urls()
        XCTAssertEqual(urls.active, nil)
        XCTAssertEqual(urls.webhook, nil)
        XCTAssertEqual(urls.api, nil)
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

        setNetworkState(NetworkState(ssid: nil))

        var webhookURL = await info.webhookURL()
        XCTAssertEqual(webhookURL, cloudhookURL)

        info.set(address: internalURL, for: .internal)
        webhookURL = await info.webhookURL()
        XCTAssertEqual(webhookURL, cloudhookURL)

        setNetworkState(NetworkState(ssid: "unit_tests"))

        webhookURL = await info.webhookURL()
        XCTAssertEqual(webhookURL, internalURL?.appendingPathComponent("api/webhook/webhook_id1"))

        setNetworkState(NetworkState(ssid: nil))
        webhookURL = await info.webhookURL()
        XCTAssertEqual(webhookURL, cloudhookURL)
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

        let url = await info.activeURL()
        XCTAssertEqual(url, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
    }

    func testAsyncActiveURLRefreshesNetworkInformationBeforeEvaluating() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: ["unit_tests"],
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        // Cached network information does not know about the internal network yet;
        // the refresh performed by the async activeURL discovers it.
        Current.connectivity.lastKnownNetworkState = { NetworkState() }
        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { NetworkState(ssid: "unit_tests") }
        }

        let url = await info.activeURL()

        XCTAssertEqual(url, internalURL)
        XCTAssertEqual(info.activeURLType, .internal)
    }

    func testAsyncActiveURLFallsBackToExternalURLWhenRefreshLeavesInternalNetwork() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")
        var info = ConnectionInfo(
            externalURL: externalURL,
            internalURL: internalURL,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: ["unit_tests"],
            internalHardwareAddresses: nil,
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        // Cached network information still says we are on the internal network,
        // but the refresh performed by the async activeURL discovers we left it.
        Current.connectivity.lastKnownNetworkState = { NetworkState(ssid: "unit_tests") }
        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { NetworkState() }
        }

        let url = await info.activeURL()

        XCTAssertEqual(url, externalURL)
        XCTAssertEqual(info.activeURLType, .external)
    }

    func testServerAsyncActiveURLRefreshesNetworkInformationAndUpdatesInfo() async {
        let internalURL = URL(string: "http://internal.example.com:8123")
        let externalURL = URL(string: "http://external.example.com:8123")

        Current.connectivity.lastKnownNetworkState = { NetworkState() }

        let server = Server.fake { info in
            info.connection.set(address: internalURL, for: .internal)
            info.connection.set(address: externalURL, for: .external)
            info.connection.internalSSIDs = ["unit_tests"]
        }

        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { NetworkState(ssid: "unit_tests") }
        }

        let url = await server.activeURL()

        XCTAssertEqual(url, internalURL)
        XCTAssertEqual(server.info.connection.activeURLType, .internal)
    }

    func testIsOnInternalNetworkFetchesFreshNetworkState() async {
        let info = ConnectionInfo(
            externalURL: nil,
            internalURL: URL(string: "http://internal.example.com:8123"),
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id1",
            webhookSecret: nil,
            internalSSIDs: ["unit_tests"],
            internalHardwareAddresses: ["aa:bb:cc:dd:ee:ff"],
            isLocalPushEnabled: false,
            securityExceptions: .init(),
            connectionAccessSecurityLevel: .undefined
        )

        Current.connectivity.currentNetworkState = { NetworkState(ssid: "unit_tests") }
        var isOnInternalNetwork = await info.isOnInternalNetwork()
        XCTAssertTrue(isOnInternalNetwork)

        Current.connectivity.currentNetworkState = { NetworkState(hardwareAddress: "aa:bb:cc:dd:ee:ff") }
        isOnInternalNetwork = await info.isOnInternalNetwork()
        XCTAssertTrue(isOnInternalNetwork)

        Current.connectivity.currentNetworkState = { NetworkState(ssid: "other") }
        isOnInternalNetwork = await info.isOnInternalNetwork()
        XCTAssertFalse(isOnInternalNetwork)
    }
}

private extension ConnectionInfo {
    /// Evaluates the async URL accessors in a fixed order so tests can assert on all of them at once.
    mutating func urls() async -> (active: URL?, webhook: URL?, api: URL?) {
        let active = await activeURL()
        let webhook = await webhookURL()
        let api = await activeAPIURL()
        return (active, webhook, api)
    }
}
