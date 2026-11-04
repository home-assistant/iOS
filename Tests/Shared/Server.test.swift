@testable import Shared
import XCTest

class ServerTests: XCTestCase {
    private var previousCurrentNetworkState: (() async -> NetworkState)!
    private var previousLastKnownNetworkState: (() -> NetworkState)!
    private var previousRefreshNetworkInformation: (() async -> Void)!

    override func setUp() {
        super.setUp()
        previousCurrentNetworkState = Current.connectivity.currentNetworkState
        previousLastKnownNetworkState = Current.connectivity.lastKnownNetworkState
        previousRefreshNetworkInformation = Current.connectivity.refreshNetworkInformation
        setNetworkState(NetworkState())
    }

    override func tearDown() {
        Current.connectivity.currentNetworkState = previousCurrentNetworkState
        Current.connectivity.lastKnownNetworkState = previousLastKnownNetworkState
        Current.connectivity.refreshNetworkInformation = previousRefreshNetworkInformation
        super.tearDown()
    }

    private func setNetworkState(_ state: NetworkState) {
        Current.connectivity.currentNetworkState = { state }
        Current.connectivity.lastKnownNetworkState = { state }
        Current.connectivity.refreshNetworkInformation = {
            Current.connectivity.lastKnownNetworkState = { state }
        }
    }

    private func waitLoop() {
        let expectation = expectation(description: "run loop")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10.0)
    }

    func testSortOrder() {
        let servers: [Server] = [
            Server(
                identifier: "1",
                getter: {
                    with(.fake()) {
                        $0.sortOrder = 100
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "2",
                getter: {
                    with(.fake()) {
                        $0.remoteName = "2"
                        $0.sortOrder = 50
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "3",
                getter: {
                    with(.fake()) {
                        $0.remoteName = "1"
                        $0.sortOrder = 50
                    }
                }, setter: { _ in
                    true
                }
            ),
            Server(
                identifier: "4",
                getter: {
                    with(.fake()) {
                        $0.sortOrder = 1000
                    }
                }, setter: { _ in
                    true
                }
            ),
        ]

        let sorted = servers.sorted()
        XCTAssertEqual(sorted.map(\.identifier), ["3", "2", "1", "4"])
    }

    func testEquality() {
        let server_id1_1 = Server(identifier: "1", getter: { .fake() }, setter: { _ in true })
        let server_id1_2 = Server(identifier: "1", getter: { .fake() }, setter: { _ in true })
        let server_id2 = Server(identifier: "2", getter: { .fake() }, setter: { _ in true })
        let server_id3 = Server(identifier: "3", getter: { .fake() }, setter: { _ in true })

        XCTAssertEqual(server_id1_1, server_id1_1)
        XCTAssertEqual(server_id1_1, server_id1_2)
        XCTAssertNotEqual(server_id1_1, server_id3)
        XCTAssertNotEqual(server_id1_2, server_id3)
        XCTAssertNotEqual(server_id2, server_id3)
    }

    func testLocalName() {
        var serverInfo = ServerInfo.fake()
        serverInfo.remoteName = "remote_name1"

        let server = Server(identifier: "fake1", getter: { serverInfo }, setter: { serverInfo = $0; return true })

        XCTAssertEqual(server.info.name, "remote_name1")

        server.info.setSetting(value: "local_name1", for: .localName)
        XCTAssertEqual(server.info.name, "local_name1")

        server.info.setSetting(value: nil, for: .localName)
        XCTAssertEqual(server.info.name, "remote_name1")

        server.info.setSetting(value: "", for: .localName)
        XCTAssertEqual(server.info.name, "remote_name1")
    }

    func testNotifyInfoChange() {
        var info: ServerInfo = .fake()

        var setterResponseValue = true

        let server = Server(
            identifier: "test",
            getter: { info },
            setter: { info = $0; return setterResponseValue }
        )

        var notifiedInfos = [ServerInfo]()

        let token = server.observe { newInfo in
            notifiedInfos.append(newInfo)
        }

        server.info = info
        XCTAssertEqual(server.info, info)
        waitLoop()
        XCTAssertTrue(notifiedInfos.isEmpty)

        server.update { info in
            info.connection.webhookSecret = "update_1"
        }

        XCTAssertEqual(server.info.connection.webhookSecret, "update_1")
        waitLoop()

        XCTAssertEqual(notifiedInfos.count, 1)
        XCTAssertEqual(notifiedInfos[0].connection.webhookSecret, "update_1")

        setterResponseValue = false

        notifiedInfos.removeAll()

        server.update { info in
            info.connection.webhookSecret = "update_2"
        }

        waitLoop()
        XCTAssertTrue(notifiedInfos.isEmpty)

        setterResponseValue = true

        token.cancel()

        notifiedInfos.removeAll()

        server.update { info in
            info.connection.webhookSecret = "update_3"
        }

        waitLoop()

        XCTAssertTrue(notifiedInfos.isEmpty)
    }

    func testMirroredForPersistenceRemovesSensitiveConnectionState() throws {
        var info = ServerInfo.fake()
        var securityExceptions = SecurityExceptions()
        try securityExceptions.add(for: .unitTestDotExampleDotCom1)

        info.connection.cloudhookURL = URL(string: "https://hooks.nabu.casa/webhook-id")
        info.connection.webhookSecret = "webhook-secret"
        info.connection.securityExceptions = securityExceptions
        info.connection.clientCertificate = ClientCertificate(
            keychainIdentifier: "client-cert-1",
            displayName: "Client Certificate"
        )

        let mirrored = info.mirroredForPersistence

        XCTAssertEqual(mirrored.token, ServerInfo.mirrorPlaceholderToken)
        XCTAssertEqual(mirrored.connection.webhookID, ServerInfo.mirrorPlaceholderWebhookID)
        XCTAssertNil(mirrored.connection.cloudhookURL)
        XCTAssertNil(mirrored.connection.webhookSecret)
        XCTAssertFalse(mirrored.connection.securityExceptions.hasExceptions)
        XCTAssertNil(mirrored.connection.clientCertificate)
    }

    func testActiveURLReturnsInternalWhenOnInternalNetwork() async {
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "http://internal.example.com:8123"), for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        info.connection.internalSSIDs = ["my_ssid"]
        let server = Server.fake(initial: info)
        setNetworkState(NetworkState(ssid: "my_ssid"))

        let url = await server.activeURL()

        XCTAssertEqual(url, info.connection.address(for: .internal))
        XCTAssertEqual(server.info.connection.activeURLType, .internal)
    }

    func testActiveURLReturnsExternalWhenNotOnInternalNetwork() async {
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "http://internal.example.com:8123"), for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        info.connection.internalSSIDs = ["my_ssid"]
        let server = Server.fake(initial: info)
        setNetworkState(NetworkState(ssid: "other_ssid"))

        let url = await server.activeURL()

        XCTAssertEqual(url, info.connection.address(for: .external))
        XCTAssertEqual(server.info.connection.activeURLType, .external)
    }

    func testActiveURLUsingLastKnownNetworkStateEvaluatesAgainstCache() {
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "http://internal.example.com:8123"), for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        info.connection.internalSSIDs = ["my_ssid"]
        let server = Server.fake(initial: info)
        setNetworkState(NetworkState(ssid: "my_ssid"))

        let url = server.activeURLUsingLastKnownNetworkState()

        XCTAssertEqual(url, info.connection.address(for: .internal))
        XCTAssertEqual(server.info.connection.activeURLType, .internal)
    }

    func testActiveAPIURLAppendsAPIPath() async {
        var info = ServerInfo.fake()
        info.connection.set(address: nil, for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        let server = Server.fake(initial: info)

        let url = await server.activeAPIURL()

        XCTAssertEqual(url, URL(string: "https://external.example.com/api"))
    }

    func testWebhookURLReturnsCloudhookWhenNotOnInternalNetwork() async {
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "http://internal.example.com:8123"), for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        info.connection.cloudhookURL = URL(string: "https://hooks.nabu.casa/webhook-id")
        info.connection.internalSSIDs = ["my_ssid"]
        let server = Server.fake(initial: info)
        setNetworkState(NetworkState(ssid: "other_ssid"))

        let url = await server.webhookURL()

        XCTAssertEqual(url, info.connection.cloudhookURL)
    }

    func testWebhookURLUsesInternalURLWhenOnInternalNetwork() async {
        var info = ServerInfo.fake()
        info.connection.set(address: URL(string: "http://internal.example.com:8123"), for: .internal)
        info.connection.set(address: URL(string: "https://external.example.com"), for: .external)
        info.connection.cloudhookURL = URL(string: "https://hooks.nabu.casa/webhook-id")
        info.connection.internalSSIDs = ["my_ssid"]
        let server = Server.fake(initial: info)
        setNetworkState(NetworkState(ssid: "my_ssid"))

        let url = await server.webhookURL()

        XCTAssertEqual(
            url,
            info.connection.address(for: .internal)?
                .appendingPathComponent("api/webhook/\(info.connection.webhookID)", isDirectory: false)
        )
    }
}
