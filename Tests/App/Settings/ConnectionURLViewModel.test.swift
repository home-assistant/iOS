import Foundation
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Editing one of a server's URLs: the form starts from the server's connection, refuses to leave
/// the server without any URL, and only writes back once saved.
@MainActor
final class ConnectionURLViewModelTests: XCTestCase {
    private var previousCurrentNetworkState: (() async -> NetworkState)!

    override func setUp() async throws {
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
    }

    override func tearDown() async throws {
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
    }

    private func makeServer(
        internalURL: URL? = URL(string: "http://internal.example.com:8123"),
        externalURL: URL? = URL(string: "https://external.example.com"),
        internalSSIDs: [String]? = ["MyWifi"],
        internalHardwareAddresses: [String]? = ["aa:bb:cc:dd:ee:ff"]
    ) -> Server {
        let info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL,
                internalURL: internalURL,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: internalSSIDs,
                internalHardwareAddresses: internalHardwareAddresses,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .mostSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return Server.fake(initial: info)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testStartsFromTheServersConnection() {
        let viewModel = ConnectionURLViewModel(server: makeServer(), urlType: .internal)

        XCTAssertEqual(viewModel.url, "http://internal.example.com:8123")
        XCTAssertFalse(viewModel.useCloud)
        XCTAssertFalse(viewModel.localPush)
        XCTAssertEqual(viewModel.ssids, ["MyWifi"])
        XCTAssertEqual(viewModel.hardwareAddresses, ["aa:bb:cc:dd:ee:ff"])
        XCTAssertFalse(viewModel.isChecking)
        XCTAssertFalse(viewModel.showError)
    }

    func testStartsEmptyWithoutAnyConfiguredValues() {
        let server = makeServer(internalURL: nil, internalSSIDs: nil, internalHardwareAddresses: nil)
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)

        XCTAssertEqual(viewModel.url, "")
        XCTAssertTrue(viewModel.ssids.isEmpty)
        XCTAssertTrue(viewModel.hardwareAddresses.isEmpty)
    }

    func testPlaceholderDependsOnTheURLType() {
        let server = makeServer()

        XCTAssertEqual(
            ConnectionURLViewModel(server: server, urlType: .internal).placeholder,
            L10n.Settings.ConnectionSection.InternalBaseUrl.placeholder
        )
        XCTAssertEqual(
            ConnectionURLViewModel(server: server, urlType: .external).placeholder,
            L10n.Settings.ConnectionSection.ExternalBaseUrl.placeholder
        )
        XCTAssertEqual(ConnectionURLViewModel(server: server, urlType: .remoteUI).placeholder, "")
        XCTAssertEqual(ConnectionURLViewModel(server: server, urlType: .none).placeholder, "")
    }

    func testRemovingSSIDsAndHardwareAddresses() {
        let server = makeServer(
            internalSSIDs: ["One", "Two", "Three"],
            internalHardwareAddresses: ["aa:aa:aa:aa:aa:aa", "bb:bb:bb:bb:bb:bb", "cc:cc:cc:cc:cc:cc"]
        )
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)

        viewModel.removeSSID(at: 1)
        XCTAssertEqual(viewModel.ssids, ["One", "Three"])
        viewModel.removeSSIDs(at: IndexSet(integer: 0))
        XCTAssertEqual(viewModel.ssids, ["Three"])

        viewModel.removeHardwareAddress(at: 0)
        XCTAssertEqual(viewModel.hardwareAddresses, ["bb:bb:bb:bb:bb:bb", "cc:cc:cc:cc:cc:cc"])
        viewModel.removeHardwareAddresses(at: IndexSet(integer: 1))
        XCTAssertEqual(viewModel.hardwareAddresses, ["bb:bb:bb:bb:bb:bb"])
    }

    func testAddingAnSSIDPrefillsTheCurrentNetwork() async throws {
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "HomeWifi") }
        let viewModel = ConnectionURLViewModel(server: makeServer(), urlType: .internal)

        viewModel.addSSID()
        try await waitUntil { viewModel.ssids.count == 2 }

        XCTAssertEqual(viewModel.ssids, ["MyWifi", "HomeWifi"])
    }

    func testAddingAnSSIDAlreadyListedAddsAnEmptyRow() async throws {
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "MyWifi") }
        let viewModel = ConnectionURLViewModel(server: makeServer(), urlType: .internal)

        viewModel.addSSID()
        try await waitUntil { viewModel.ssids.count == 2 }

        XCTAssertEqual(viewModel.ssids, ["MyWifi", ""])
    }

    func testAddingAHardwareAddressPrefillsTheCurrentOne() async throws {
        Current.connectivity.currentNetworkState = { NetworkState(hardwareAddress: "11:22:33:44:55:66") }
        let viewModel = ConnectionURLViewModel(server: makeServer(), urlType: .internal)

        viewModel.addHardwareAddress()
        try await waitUntil { viewModel.hardwareAddresses.count == 2 }

        XCTAssertEqual(viewModel.hardwareAddresses, ["aa:bb:cc:dd:ee:ff", "11:22:33:44:55:66"])
    }

    func testAddingAHardwareAddressWithoutANetworkAddsAnEmptyRow() async throws {
        Current.connectivity.currentNetworkState = { NetworkState() }
        let viewModel = ConnectionURLViewModel(server: makeServer(), urlType: .internal)

        viewModel.addHardwareAddress()
        try await waitUntil { viewModel.hardwareAddresses.count == 2 }

        XCTAssertEqual(viewModel.hardwareAddresses, ["aa:bb:cc:dd:ee:ff", ""])
    }

    func testClearingTheOnlyURLIsRefused() async throws {
        let server = makeServer(internalURL: nil)
        let viewModel = ConnectionURLViewModel(server: server, urlType: .external)
        viewModel.url = ""
        var succeeded = false

        viewModel.save(onSuccess: { succeeded = true })
        try await waitUntil { viewModel.showError }

        XCTAssertTrue(viewModel.showError)
        XCTAssertFalse(succeeded)
        XCTAssertFalse(viewModel.canCommitAnyway)
        XCTAssertFalse(viewModel.isChecking)
        XCTAssertEqual(viewModel.errorMessage, L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl)
        XCTAssertEqual(server.info.connection.address(for: .external), URL(string: "https://external.example.com"))
    }

    /// With the external URL still there, clearing the internal one needs no reachability check.
    func testClearingOneOfTwoURLsSavesStraightAway() async throws {
        let server = makeServer()
        let viewModel = ConnectionURLViewModel(server: server, urlType: .internal)
        viewModel.url = ""
        viewModel.localPush = true
        viewModel.ssids = ["Home", ""]
        viewModel.hardwareAddresses = ["AA:BB:CC:DD:EE:FF", ""]
        var succeeded = false

        viewModel.save(onSuccess: { succeeded = true })
        try await waitUntil { succeeded }

        XCTAssertTrue(succeeded)
        XCTAssertFalse(viewModel.showError)
        XCTAssertFalse(viewModel.isChecking)
        XCTAssertNil(server.info.connection.address(for: .internal))
        XCTAssertEqual(server.info.connection.address(for: .external), URL(string: "https://external.example.com"))
        XCTAssertTrue(server.info.connection.isLocalPushEnabled)
        XCTAssertEqual(server.info.connection.internalSSIDs, ["Home"])
        XCTAssertEqual(server.info.connection.internalHardwareAddresses, ["aa:bb:cc:dd:ee:ff"])
    }

    func testCommitAnywayWritesTheFormWithoutChecking() {
        let server = makeServer()
        let viewModel = ConnectionURLViewModel(server: server, urlType: .external)
        viewModel.url = "http://new.example.com:8123"
        var succeeded = false

        viewModel.commitAnyway(onSuccess: { succeeded = true })

        XCTAssertTrue(succeeded)
        XCTAssertEqual(server.info.connection.address(for: .external), URL(string: "http://new.example.com:8123"))
        XCTAssertEqual(server.info.connection.address(for: .internal), URL(string: "http://internal.example.com:8123"))
    }

    func testSaveErrorsDescribeThemselvesAndAreFinal() {
        let lastURL = ConnectionURLViewModel.SaveError.lastURL
        let validation = ConnectionURLViewModel.SaveError.validation("Not a MAC address")

        XCTAssertEqual(lastURL.errorDescription, L10n.Settings.ConnectionSection.Errors.cannotRemoveLastUrl)
        XCTAssertEqual(validation.errorDescription, "Not a MAC address")
        XCTAssertTrue(lastURL.isFinal)
        XCTAssertTrue(validation.isFinal)
    }
}
