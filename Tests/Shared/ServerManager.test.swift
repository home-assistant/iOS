@testable import Shared
import Version
import XCTest

class ServerManagerTests: XCTestCase {
    private var encoder: JSONEncoder!
    private var keychain: FakeServerManagerKeychain!
    private var historicKeychain: FakeServerManagerKeychain!
    private var servers: ServerManagerImpl!

    override func setUp() {
        super.setUp()

        encoder = .init()
        keychain = .init()
        historicKeychain = .init()

        Current.settingsStore.prefs.removeObject(forKey: "deletedServers")
    }

    private func setupRegular(
        _ serverInfos: [String: ServerInfo] = [:]
    ) throws {
        for (key, value) in serverInfos {
            try keychain.set(encoder.encode(value), key: key)
        }

        servers = ServerManagerImpl(keychain: keychain, historicKeychain: historicKeychain)
        servers.setup()
    }

    func testInitiallyEmptyAndGainingServersWithCaching() throws {
        Current.isAppExtension = false
        try base_testInitiallyEmptyAndGainingServers()
    }

    func testInitiallyEmptyAndGainingServersWithoutCaching() throws {
        Current.isAppExtension = true
        try base_testInitiallyEmptyAndGainingServers()
    }

    private func base_testInitiallyEmptyAndGainingServers() throws {
        try setupRegular()

        let observer = FakeObserver()

        func expectingObserver(_ block: () -> Void) {
            let expectation = observer.addExpectation(from: self)
            block()
            wait(for: [expectation], timeout: 10.0)
        }

        servers.add(observer: observer)

        XCTAssertEqual(servers.all.count, 0)

        XCTAssertNil(servers.server(for: "fake1"))
        XCTAssertNil(servers.server(forServerIdentifier: "fake1"))
        XCTAssertNil(servers.server(forWebhookID: "fake1"))
        XCTAssertNil(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake1")))
        XCTAssertNil(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake1"), fallback: false))

        let state = servers.restorableState()
        XCTAssertEqual(String(decoding: state, as: UTF8.self), "{}")

        expectingObserver {
            servers.restoreState(state)
        }
        XCTAssertEqual(servers.all.count, 0)
        XCTAssertTrue(keychain.data.isEmpty)

        let info1 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook1"
        }

        let info2 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook2"
        }

        let info3 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook3"
        }

        expectingObserver {
            servers.add(identifier: "fake1", serverInfo: info1)
        }
        let server1 = try XCTUnwrap(servers.server(for: "fake1"))
        XCTAssertTrue(servers.server(forWebhookID: "webhook1") === server1)
        XCTAssertTrue(servers.server(forServerIdentifier: "fake1") === server1)
        XCTAssertTrue(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake1")) === server1)
        XCTAssertTrue(
            servers
                .server(for: FakeServerIntentProviding(server: .init(identifier: "fake1", display: "fake1"))) ===
                server1
        )
        XCTAssertEqual(server1.info, with(info1) {
            $0.sortOrder = 0
        })

        XCTAssertEqual(servers.all, [server1])

        expectingObserver {
            servers.add(identifier: "fake2", serverInfo: info2)
        }
        let server2 = try XCTUnwrap(servers.server(for: "fake2"))
        XCTAssertTrue(servers.server(forWebhookID: "webhook2") === server2)
        XCTAssertTrue(servers.server(forServerIdentifier: "fake2") === server2)
        XCTAssertTrue(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake2")) === server2)
        XCTAssertTrue(
            servers
                .server(for: FakeServerIntentProviding(server: .init(identifier: "fake2", display: "fake1"))) ===
                server2
        )
        XCTAssertEqual(server2.info, with(info2) {
            $0.sortOrder = 1000
        })

        XCTAssertEqual(servers.all, [server1, server2])

        try XCTAssertEqual(keychain.getData("fake1"), encoder.encode(server1.info))
        try XCTAssertEqual(keychain.getData("fake2"), encoder.encode(server2.info))
        XCTAssertEqual(keychain.data.count, 2)

        let stateS1S2 = servers.restorableState()

        expectingObserver {
            server1.info.connection.webhookID = "webhook1_2"
        }
        XCTAssertEqual(server1.info.connection.webhookID, "webhook1_2")
        try XCTAssertEqual(keychain.getData("fake1"), encoder.encode(server1.info))

        expectingObserver {
            servers.remove(identifier: "fake1")
        }
        try XCTAssertNil(keychain.getData("fake1"))

        // grab it, which may also side-effect insert into cache, if buggy
        _ = server1.info

        expectingObserver {
            // we just deleted it, so we re-add it to make sure _that_ works
            let tempFake1 = with(info1) {
                $0.connection.webhookID = "deleted_and_reset"
            }
            servers.add(identifier: "fake1", serverInfo: tempFake1)
            XCTAssertEqual(servers.server(for: "fake1")?.info.connection.webhookID, "deleted_and_reset")
        }

        expectingObserver {
            servers.remove(identifier: "fake1")
        }

        XCTAssertNil(servers.server(for: "fake1"))
        XCTAssertEqual(servers.all, [server2])

        var server3: Server!

        expectingObserver {
            server3 = servers.add(identifier: "fake3", serverInfo: info3)
        }
        XCTAssertEqual(servers.all, [server2, server3])
        try XCTAssertEqual(keychain.getData("fake3"), encoder.encode(server3.info))
        XCTAssertEqual(server3.info, with(info3) {
            $0.sortOrder = 2000
        })

        let stateS2S3 = servers.restorableState()

        expectingObserver {
            servers.removeAll()
        }
        XCTAssertEqual(servers.all, [])
        XCTAssertNil(servers.server(for: "fake1"))
        XCTAssertNil(servers.server(for: "fake2"))
        XCTAssertNil(servers.server(for: "fake3"))
        XCTAssertTrue(keychain.data.isEmpty)

        expectingObserver {
            servers.restoreState(stateS2S3)
        }
        XCTAssertEqual(servers.all.map(\.identifier), ["fake2", "fake3"])
        XCTAssertEqual(Set(keychain.data.keys), Set(["fake2", "fake3"]))

        XCTAssertNil(servers.server(for: "fake1"))
        XCTAssertEqual(servers.server(for: "fake2")?.info, with(info2) {
            $0.sortOrder = 1000
        })
        XCTAssertEqual(servers.server(for: "fake3")?.info, with(info3) {
            $0.sortOrder = 2000
        })

        let server2_afterRestore = try XCTUnwrap(servers.server(for: "fake2"))
        expectingObserver {
            server2_afterRestore.info.connection.webhookID = "webhook2_2"
        }

        if Current.isAppExtension {
            // do it again to handle the restricted caching case - this should notify even with no change
            expectingObserver {
                server2_afterRestore.info.connection.webhookID = "webhook2_2"
            }
        } else {
            // opposite - should not notify
            server2_afterRestore.info.connection.webhookID = "webhook2_2"
        }

        XCTAssertEqual(servers.server(for: "fake2")?.info.connection.webhookID, "webhook2_2")
        try XCTAssertEqual(keychain.getData("fake2"), encoder.encode(server2_afterRestore.info))

        let s2RestoreExpectation = expectation(description: "server2notify")
        _ = server2_afterRestore.observe { info in
            XCTAssertEqual(info.connection.webhookID, "webhook2")
            s2RestoreExpectation.fulfill()
        }

        expectingObserver {
            servers.restoreState(stateS1S2)
        }
        wait(for: [s2RestoreExpectation], timeout: 10.0)
        XCTAssertEqual(servers.all.map(\.identifier), ["fake1", "fake2"])
        XCTAssertEqual(Set(keychain.data.keys), Set(["fake1", "fake2"]))

        XCTAssertEqual(servers.server(for: "fake1")?.info, with(info1) {
            $0.sortOrder = 0
        })
        XCTAssertEqual(servers.server(for: "fake2")?.info, with(info2) {
            $0.sortOrder = 1000
        })
        XCTAssertNil(servers.server(for: "fake3"))

        servers.remove(observer: observer)
        servers.removeAll()
        XCTAssertTrue(servers.all.isEmpty)
        XCTAssertTrue(keychain.data.isEmpty)
    }

    func testWithInitialServers() throws {
        let info1 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook1"
            $0.sortOrder = 3
        }

        let info2 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook2"
            $0.sortOrder = 2
        }

        let info3 = with(ServerInfo.fake()) {
            $0.connection.webhookID = "webhook3"
            $0.sortOrder = 1
        }

        try setupRegular([
            "fake1": info1,
            "fake2": info2,
            "fake3": info3,
        ])

        let server1 = try XCTUnwrap(servers.server(for: "fake1"))
        let server2 = try XCTUnwrap(servers.server(for: "fake2"))
        let server3 = try XCTUnwrap(servers.server(for: "fake3"))

        XCTAssertEqual(server1.info, info1)
        XCTAssertEqual(server2.info, info2)
        XCTAssertEqual(server3.info, info3)
        XCTAssertEqual(servers.all, [server3, server2, server1])
    }

    func testSortOrder() throws {
        try setupRegular([
            "fake1": with(.fake()) {
                $0.sortOrder = 1
            },
            "fake2": with(.fake()) {
                $0.sortOrder = 2
            },
            "fake3": with(.fake()) {
                $0.sortOrder = 3
            },
        ])

        XCTAssertEqual(servers.all.map(\.identifier), ["fake1", "fake2", "fake3"])

        servers.server(for: "fake2")?.info.sortOrder = 10
        XCTAssertEqual(servers.all.map(\.identifier), ["fake1", "fake3", "fake2"])

        servers.server(for: "fake3")?.info.sortOrder = 0
        XCTAssertEqual(servers.all.map(\.identifier), ["fake3", "fake1", "fake2"])
    }

    private func notificationContent(webhookID: String?) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if let webhookID = webhookID {
            content.userInfo["webhook_id"] = webhookID
        }
        return content
    }

    func testServerGetterHelpersWith1Server() throws {
        try setupRegular([
            "fake1": with(.fake()) {
                $0.sortOrder = 1
                $0.connection.webhookID = "webhook1"
            },
        ])

        let server1 = servers.server(for: "fake1")
        let intentServer1 = IntentServer(identifier: "fake1", display: "fake1")
        let intentServer2 = IntentServer(identifier: "fake2", display: "fake2")

        XCTAssertEqual(servers.server(forServerIdentifier: nil), nil)
        XCTAssertEqual(servers.server(forServerIdentifier: "fake1"), server1)
        XCTAssertEqual(servers.server(forServerIdentifier: "fake2"), nil)

        XCTAssertEqual(servers.server(forWebhookID: "webhook1"), server1)
        XCTAssertEqual(servers.server(forWebhookID: "webhook2"), nil)

        XCTAssertEqual(servers.server(for: notificationContent(webhookID: "webhook1")), server1)
        XCTAssertEqual(servers.server(for: notificationContent(webhookID: "webhook2")), nil)
        XCTAssertEqual(servers.server(for: notificationContent(webhookID: nil)), server1)

        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer1)), server1)
        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer2)), server1)
        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer2), fallback: false), nil)

        XCTAssertEqual(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake1")), server1)
        XCTAssertEqual(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake2")), server1)
        XCTAssertEqual(
            servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake2"), fallback: false),
            nil
        )
    }

    func testServerGetterHelpersWith2Server() throws {
        try setupRegular([
            "fake1": with(.fake()) {
                $0.sortOrder = 1
                $0.connection.webhookID = "webhook1"
            },
            "fake2": with(.fake()) {
                $0.sortOrder = 2
                $0.connection.webhookID = "webhook2"
            },
        ])

        let server1 = servers.server(for: "fake1")
        let server2 = servers.server(for: "fake2")
        let intentServer1 = IntentServer(identifier: "fake1", display: "fake1")
        let intentServer2 = IntentServer(identifier: "fake2", display: "fake2")
        let intentServer3 = IntentServer(identifier: "fake3", display: "fake3")

        XCTAssertEqual(servers.server(forServerIdentifier: nil), nil)
        XCTAssertEqual(servers.server(forServerIdentifier: "fake1"), server1)
        XCTAssertEqual(servers.server(forServerIdentifier: "fake2"), server2)
        XCTAssertEqual(servers.server(forServerIdentifier: "fake3"), nil)

        XCTAssertEqual(servers.server(forWebhookID: "webhook1"), server1)
        XCTAssertEqual(servers.server(forWebhookID: "webhook2"), server2)
        XCTAssertEqual(servers.server(forWebhookID: "webhook3"), nil)

        XCTAssertEqual(servers.server(for: notificationContent(webhookID: "webhook1")), server1)
        XCTAssertEqual(servers.server(for: notificationContent(webhookID: "webhook2")), server2)
        XCTAssertEqual(servers.server(for: notificationContent(webhookID: nil)), server1)
        XCTAssertEqual(servers.server(for: notificationContent(webhookID: "webhook3")), nil)

        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer1)), server1)
        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer2)), server2)
        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer3)), nil)
        XCTAssertEqual(servers.server(for: FakeServerIntentProviding(server: intentServer3), fallback: false), nil)

        XCTAssertEqual(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake1")), server1)
        XCTAssertEqual(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake2")), server2)
        XCTAssertEqual(servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake3")), nil)
        XCTAssertEqual(
            servers.server(for: FakeServerIdentifierProviding(serverIdentifier: "fake3"), fallback: false),
            nil
        )
    }

    func testServerUpdatePerField() throws {
        try setupRegular([
            "fake1": with(.fake()) {
                $0.sortOrder = 1
                $0.connection.webhookID = "webhook1"
            },
        ])

        var decoded: ServerInfo {
            get throws {
                try JSONDecoder().decode(ServerInfo.self, from: try XCTUnwrap(keychain.data["fake1"]))
            }
        }

        let server = try XCTUnwrap(servers.all.first)
        server.info.remoteName = "updated_name"
        XCTAssertEqual(server.info.remoteName, "updated_name")
        XCTAssertEqual(try decoded.remoteName, "updated_name")

        server.info.sortOrder = 3
        XCTAssertEqual(server.info.sortOrder, 3)
        XCTAssertEqual(try decoded.sortOrder, 3)

        server.info.version = Version(major: 11)
        XCTAssertEqual(server.info.version.major, 11)
        XCTAssertEqual(try decoded.version.major, 11)

        server.info.connection.webhookID = "webhook2"
        XCTAssertEqual(server.info.connection.webhookID, "webhook2")
        XCTAssertEqual(try decoded.connection.webhookID, "webhook2")

        server.info.token.accessToken = "access2"
        XCTAssertEqual(server.info.token.accessToken, "access2")
        XCTAssertEqual(try decoded.token.accessToken, "access2")
    }

    func testUpdateAfterDeleteDoesntPersist() throws {
        try setupRegular()

        let oldServers = try XCTUnwrap(servers)
        let oldServer1 = oldServers.add(identifier: "fake1", serverInfo: .fake())

        try setupRegular()

        let newServer1 = try XCTUnwrap(servers.server(for: oldServer1.identifier))
        oldServers.remove(identifier: oldServer1.identifier)

        newServer1.info.remoteName = "updated"
        XCTAssertTrue(keychain.data.isEmpty)

        let newInfo = with(newServer1.info) {
            $0.remoteName = "new_name1"
        }
        servers.add(identifier: newServer1.identifier, serverInfo: newInfo)
        XCTAssertEqual(keychain.data[newServer1.identifier.rawValue], try encoder.encode(newInfo))
    }

    func testUpdateAfterDeleteInAnotherProcessDoesntPersist() throws {
        try setupRegular()

        let server1 = servers.add(identifier: "fake1", serverInfo: .fake())
        servers.remove(identifier: server1.identifier)

        try setupRegular()

        server1.info.remoteName = "updated"
        XCTAssertTrue(keychain.data.isEmpty)

        let newInfo = with(server1.info) {
            $0.remoteName = "new_name1"
        }
        servers.add(identifier: server1.identifier, serverInfo: newInfo)
        XCTAssertEqual(keychain.data[server1.identifier.rawValue], try encoder.encode(newInfo))
    }

    func testThreadsafeChangesWithoutCaching() throws {
        Current.isAppExtension = true
        try base_testThreadsafeChanges()
    }

    func testThreadsafeChangesWithCaching() throws {
        Current.isAppExtension = false
        try base_testThreadsafeChanges()
    }

    private func base_testThreadsafeChanges() throws {
        try setupRegular()

        enum ActionType {
            case insertExisting(newValue: Bool)
            case insertNew
            case mutate
            case delete
        }

        let cases: [ActionType] = [
            // weight a little heavier the normal ones
            .insertNew,
            .insertNew,
            .mutate,
            .mutate,
            .delete,
            .delete,
            // the rest
            .insertExisting(newValue: false),
            .insertExisting(newValue: true),
        ]

        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            let randomServerInfo: ServerInfo = with(.fake()) {
                $0.connection.webhookID = UUID().uuidString
            }

            switch cases.randomElement()! {
            case .insertNew:
                let added = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: randomServerInfo)
                _ = servers.server(for: added.identifier)
            case let .insertExisting(newValue):
                if let random = servers.all.randomElement() {
                    let used: ServerInfo = newValue ? randomServerInfo : .fake()
                    servers.add(identifier: random.identifier, serverInfo: used)
                    _ = servers.server(for: random.identifier)
                }
            case .mutate:
                if let random = servers.all.randomElement() {
                    random.info = randomServerInfo
                    _ = servers.server(for: random.identifier)
                }
            case .delete:
                if let random = servers.all.randomElement() {
                    servers.remove(identifier: random.identifier)
                    _ = servers.server(for: random.identifier)
                }
            }
        }
    }

    private struct HistoricInfo {
        var connectionInfo: ConnectionInfo
        var tokenInfo: TokenInfo
    }

    private func setupHistoric(
        version: String?,
        overrideDeviceName: String?,
        locationName: String?
    ) throws -> HistoricInfo {
        let connectionInfo = ConnectionInfo(
            externalURL: URL(string: "http://external.local:8123")!,
            internalURL: URL(string: "http://internal.local:8123")!,
            cloudhookURL: nil,
            remoteUIURL: nil,
            webhookID: "webhook_id",
            webhookSecret: "webhook_secret",
            internalSSIDs: ["internal_ssid"],
            internalHardwareAddresses: ["internal_hardware"],
            isLocalPushEnabled: true,
            securityExceptions: .init()
        )

        let tokenInfo = TokenInfo(
            accessToken: "access_token",
            refreshToken: "refresh_token",
            expiration: Date(timeIntervalSinceNow: 1000)
        )

        try historicKeychain.set(try encoder.encode(connectionInfo), key: "connectionInfo")
        try historicKeychain.set(try encoder.encode(tokenInfo), key: "tokenInfo")
        Current.settingsStore.prefs.set(version, forKey: "version")
        Current.settingsStore.prefs.set(overrideDeviceName, forKey: "override_device_name")
        Current.settingsStore.prefs.set(locationName, forKey: "location_name")

        servers = ServerManagerImpl(keychain: keychain, historicKeychain: historicKeychain)
        servers.setup()

        return .init(connectionInfo: connectionInfo, tokenInfo: tokenInfo)
    }

    func testEmptyMigrateWithFullData() throws {
        let setupInfo = try setupHistoric(
            version: "2021.96",
            overrideDeviceName: "device_name_1",
            locationName: "location_name_1"
        )

        XCTAssertEqual(servers.all.count, 1)

        // added the server
        let server = try XCTUnwrap(servers.server(for: Server.historicId))
        XCTAssertEqual(server.info.connection, setupInfo.connectionInfo)
        XCTAssertEqual(server.info.token, setupInfo.tokenInfo)
        XCTAssertEqual(server.info.version, Version(major: 2021, minor: 96))
        XCTAssertEqual(server.info.name, "location_name_1")
        XCTAssertEqual(server.info.setting(for: .overrideDeviceName), "device_name_1")

        // removed the old keychain
        XCTAssertTrue(historicKeychain.data.isEmpty)
    }

    func testEmptyMigrateWithMinimalData() throws {
        let setupInfo = try setupHistoric(
            version: nil,
            overrideDeviceName: nil,
            locationName: nil
        )

        XCTAssertEqual(servers.all.count, 1)

        // added the server
        let server = try XCTUnwrap(servers.server(for: Server.historicId))
        XCTAssertEqual(server.info.connection, setupInfo.connectionInfo)
        XCTAssertEqual(server.info.token, setupInfo.tokenInfo)
        XCTAssertEqual(server.info.version, Version(major: 2021, minor: 1))
        XCTAssertEqual(server.info.name, ServerInfo.defaultName)
        XCTAssertNil(server.info.setting(for: .overrideDeviceName))

        // removed the old keychain
        XCTAssertTrue(historicKeychain.data.isEmpty)
    }

    func testMigrateDoesntOccurWithExisting() throws {
        try setupRegular(["existing": .fake()])
        _ = try setupHistoric(version: nil, overrideDeviceName: nil, locationName: nil)

        XCTAssertEqual(servers.all.count, 1)
        XCTAssertNotNil(servers.server(for: "existing"))
        XCTAssertNil(servers.server(for: Server.historicId))
    }
}

class FakeServerManagerKeychain: ServerManagerKeychain {
    var data = [String: Data]()

    func removeAll() throws {
        data.removeAll()
    }

    func allKeys() -> [String] {
        Array(data.keys)
    }

    func getData(_ key: String) throws -> Data? {
        data[key]
    }

    func set(_ value: Data, key: String) throws {
        data[key] = value
    }

    func remove(_ key: String) throws {
        data.removeValue(forKey: key)
    }
}

private struct FakeServerIdentifierProviding: ServerIdentifierProviding {
    var serverIdentifier: String
}

private struct FakeServerIntentProviding: ServerIntentProviding {
    var server: IntentServer?
}

private class FakeObserver: ServerObserver {
    var expectation: XCTestExpectation?

    func addExpectation(from testCase: XCTestCase) -> XCTestExpectation {
        let expectation = testCase.expectation(description: "server observer")
        self.expectation = expectation
        return expectation
    }

    func serversDidChange(_ serverManager: ServerManager) {
        if let expectation = expectation {
            expectation.fulfill()
        } else {
            XCTFail("observed without expectation")
        }
    }
}
