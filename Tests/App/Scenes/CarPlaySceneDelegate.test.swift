import CarPlay
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The CarPlay scene delegate without a car: it builds its tabs from the stored configuration as the
/// database observation reports it, keeps them when only content changes, and feeds entity states
/// from the mock connection's subscriptions to the tabs. Connecting to a real CarPlay scene is left
/// to the OS.
final class CarPlaySceneDelegateTests: XCTestCase {
    private final class StubMagicItemProvider: MagicItemProviderProtocol {
        func loadInformation(completion: @escaping ([String: [HAAppEntity]]) -> Void) {
            completion([:])
        }

        func loadInformation() async -> [String: [HAAppEntity]] {
            [:]
        }

        func getInfo(for item: MagicItem) -> MagicItem.Info? {
            .init(id: item.id, name: item.id, iconName: "", customization: nil)
        }

        func getAreaName(for item: MagicItem) -> String? {
            nil
        }
    }

    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousMagicItemProvider: (() -> MagicItemProviderProtocol)!
    private var previousPreferredServer: Any?
    private var database: DatabaseQueue!
    private var servers: FakeServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var sut: CarPlaySceneDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database
        previousMagicItemProvider = Current.magicItemProvider
        previousPreferredServer = prefs.object(forKey: CarPlayPreferredServer.preferenceKey)
        prefs.removeObject(forKey: CarPlayPreferredServer.preferenceKey)
        let database = try CarPlayTestDatabase.make()
        self.database = database
        Current.database = { database }
        Current.magicItemProvider = { StubMagicItemProvider() }
        servers = FakeServerManager()
        Current.servers = servers
        let recent = Server.fake(update: { info in
            info.version = Version(major: 2025, minor: 1, patch: 0)
        })
        server = servers.add(identifier: recent.identifier, serverInfo: recent.info)
        let api = HomeAssistantAPI(server: server)
        let mock = HAMockConnection()
        api.connection = mock
        Current.cachedApis[server.identifier] = api
        connection = mock
    }

    override func tearDown() {
        sut = nil
        connection?.pendingRequests.removeAll()
        connection?.pendingSubscriptions.removeAll()
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.database = previousDatabase
        Current.magicItemProvider = previousMagicItemProvider
        prefs.set(previousPreferredServer, forKey: CarPlayPreferredServer.preferenceKey)
        previousServers = nil
        previousDatabase = nil
        previousMagicItemProvider = nil
        previousPreferredServer = nil
        database = nil
        servers = nil
        server = nil
        connection = nil
        super.tearDown()
    }

    private func save(_ config: CarPlayConfig) throws {
        try database.write { db in try config.insert(db, onConflict: .replace) }
    }

    private func spinUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(10)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "condition not met within 10 s", file: file, line: line)
    }

    private func entityItem(_ id: String, serverId: String? = nil) -> MagicItem {
        MagicItem(id: id, serverId: serverId ?? server.identifier.rawValue, type: .entity)
    }

    private func folder(_ id: String, items: [MagicItem] = []) -> MagicItem {
        MagicItem(id: id, serverId: "", type: .folder, displayText: id, items: items)
    }

    private func entitySubscriptions() -> [HAMockConnection.PendingSubscription] {
        connection.pendingSubscriptions.filter { $0.request.type == .subscribeEntities }
    }

    /// The compressed `subscribe_entities` payload for a few entities.
    private func states(_ entities: [String: String]) -> HAData {
        .dictionary([
            "a": entities.mapValues { state -> [String: Any] in
                ["s": state, "a": [String: Any](), "c": "context", "lc": 0.0, "lu": 0.0]
            },
        ])
    }

    func testWithoutAConfigurationQuickAccessAndSettingsAreShown() {
        sut = CarPlaySceneDelegate()
        sut.setup()

        spinUntil { self.sut.allTemplates.count == 2 }
        XCTAssertTrue(sut.allTemplates.contains { $0 is CarPlayQuickAccessTemplate })
        XCTAssertTrue(sut.allTemplates.contains { $0 is CarPlayServersListTemplate })
        XCTAssertFalse(entitySubscriptions().isEmpty, "the selected server's states are subscribed to")
    }

    /// Every configured tab is built, a folder tab whose folder is gone is skipped, and a content
    /// change keeps the same tab instances.
    func testTheConfiguredTabsAreBuiltAndKeptAcrossContentChanges() throws {
        let unreachable = Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        })
        servers.add(identifier: unreachable.identifier, serverInfo: unreachable.info)
        try save(CarPlayConfig(
            tabs: [.quickAccess, .areas, .domains, .settings, .folder(folderId: "errands"), .folder(folderId: "gone")],
            quickAccessItems: [
                entityItem("light.kitchen"),
                folder("errands", items: [entityItem("switch.garage")]),
                entityItem("light.attic", serverId: unreachable.identifier.rawValue),
                entityItem("light.elsewhere", serverId: "missing-server"),
            ]
        ))
        sut = CarPlaySceneDelegate()
        sut.setup()

        spinUntil { self.sut.allTemplates.count == 5 }
        let before = sut.allTemplates.map { ObjectIdentifier($0.template) }
        let subscriptionsBefore = entitySubscriptions().count

        // A new entity changes what Quick Access subscribes to, but not the tabs.
        try save(CarPlayConfig(
            tabs: [.quickAccess, .areas, .domains, .settings, .folder(folderId: "errands"), .folder(folderId: "gone")],
            quickAccessItems: [
                entityItem("light.kitchen"),
                entityItem("light.new"),
                folder("errands", items: [entityItem("switch.garage")]),
            ]
        ))
        spinUntil { self.entitySubscriptions().count > subscriptionsBefore }
        XCTAssertEqual(Set(sut.allTemplates.map { ObjectIdentifier($0.template) }), Set(before))

        try save(CarPlayConfig(tabs: [.settings], quickAccessItems: []))
        spinUntil { self.sut.allTemplates.count == 1 }
        XCTAssertTrue(sut.allTemplates.first is CarPlayServersListTemplate)
    }

    func testMoreTabsThanCarPlayShowsAreTruncated() throws {
        let folders = (0 ..< Int(CPTabBarTemplate.maximumTabCount)).map { folder("folder-\($0)") }
        try save(CarPlayConfig(
            tabs: [.quickAccess, .settings] + folders.map { .folder(folderId: $0.id) },
            quickAccessItems: folders
        ))
        sut = CarPlaySceneDelegate()
        sut.setup()

        spinUntil { self.sut.allTemplates.count == Int(CPTabBarTemplate.maximumTabCount) }
    }

    /// States from the selected server reach the tabs, and are replayed when a tab reappears.
    func testStatesReachTheTabsAndReplayWhenTheyReappear() throws {
        try save(CarPlayConfig(
            tabs: [.quickAccess, .areas, .domains, .settings, .folder(folderId: "errands")],
            quickAccessItems: [entityItem("light.kitchen"), folder("errands", items: [entityItem("switch.fan")])]
        ))
        sut = CarPlaySceneDelegate()
        sut.setup()
        spinUntil { self.sut.allTemplates.count == 5 }
        spinUntil { self.entitySubscriptions().count >= 2 }

        let payload = states(["light.kitchen": "on", "switch.fan": "off", "cover.garage": "closed"])
        for subscription in entitySubscriptions() {
            subscription.initiated(.success(.empty))
            subscription.handler(subscription.cancellable, payload)
        }

        let domains = try XCTUnwrap(sut.allTemplates.compactMap { $0 as? CarPlayDomainsListTemplate }.first)
        spinUntil { !domains.template.sections.flatMap(\.items).isEmpty }

        for provider in sut.allTemplates {
            sut.templateWillAppear(provider.template, animated: false)
            sut.templateWillDisappear(provider.template, animated: false)
        }
        spinUntil { !domains.template.sections.flatMap(\.items).isEmpty }
    }
}
