import CoreLocation
import Foundation
import GRDB
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import XCTest

final class LegacyModelManagerDefaultsTests: XCTestCase {
    private var database: DatabaseQueue!
    private var manager: LegacyModelManager!
    private var servers: FakeServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousDate: (() -> Date)!
    private var previousServers: ServerManager!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try LocationHistoryTable().createIfNeeded(database: database)
        try LocationErrorTable().createIfNeeded(database: database)
        try AppZoneTable().createIfNeeded(database: database)
        try NotificationCategoryTable().createIfNeeded(database: database)

        servers = FakeServerManager(initial: 0)
        servers.add(identifier: "s1", serverInfo: .fake())

        manager = LegacyModelManager()
        manager.workQueue = DispatchQueue(label: "LegacyModelManagerDefaultsTests")

        previousDatabase = Current.database
        previousDate = Current.date
        previousServers = Current.servers

        let fixedNow = now
        Current.database = { self.database }
        Current.date = { fixedNow }
        Current.servers = servers
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.date = previousDate
        Current.servers = previousServers
        manager = nil

        super.tearDown()
    }

    func testDefaultCleanupDefinitions() throws {
        XCTAssertEqual(LegacyModelManager.CleanupDefinition.defaults.count, 5)

        var oldHistory = LocationHistoryEntry(
            updateType: .Manual,
            location: CLLocation(latitude: 1, longitude: 2),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "old"
        )
        oldHistory.createdAt = now.addingTimeInterval(-300 * 60 * 60)
        var recentHistory = oldHistory
        recentHistory.id = "recent-history"
        recentHistory.payload = "recent"
        recentHistory.createdAt = now.addingTimeInterval(-60 * 60)

        var oldError = LocationError(err: CLError(.denied))
        oldError.createdAt = now.addingTimeInterval(-300 * 60 * 60)
        var recentError = LocationError(err: CLError(.network))
        recentError.createdAt = now.addingTimeInterval(-60)

        let keptZone = AppZone(entityId: "zone.home", serverIdentifier: "s1")
        let orphanZone = AppZone(entityId: "zone.home", serverIdentifier: "gone")

        let keptCategory = NotificationCategory(
            identifier: "SERVER_S1",
            serverIdentifier: "s1",
            isServerControlled: true
        )
        let orphanServerCategory = NotificationCategory(
            identifier: "SERVER_GONE",
            serverIdentifier: "gone",
            isServerControlled: true
        )
        let orphanLocalCategory = NotificationCategory(
            identifier: "LOCAL_GONE",
            serverIdentifier: "gone",
            isServerControlled: false
        )

        try database.write { db in
            try oldHistory.save(db)
            try recentHistory.save(db)
            try oldError.save(db)
            try recentError.save(db)
            try keptZone.save(db)
            try orphanZone.save(db)
            try keptCategory.save(db)
            try orphanServerCategory.save(db)
            try orphanLocalCategory.save(db)
        }

        XCTAssertNoThrow(try hang(manager.cleanup()))

        let history = try database.read { try LocationHistoryEntry.fetchAll($0) }
        XCTAssertEqual(history.map(\.payload), ["recent"])

        let errors = try database.read { try LocationError.fetchAll($0) }
        XCTAssertEqual(errors.map(\.id), [recentError.id])

        let zones = try database.read { try AppZone.fetchAll($0) }
        XCTAssertEqual(zones.map(\.identifier), [keptZone.identifier])

        let categories = try database.read { try NotificationCategory.fetchAll($0) }
        XCTAssertEqual(Set(categories.map(\.identifier)), ["SERVER_S1", "LOCAL_GONE"])
        let reassigned = try XCTUnwrap(categories.first(where: { $0.identifier == "LOCAL_GONE" }))
        XCTAssertEqual(reassigned.serverIdentifier, "s1")
    }

    func testOrphanReassignWithoutServersLeavesRowsAlone() throws {
        servers.removeAll()

        let category = NotificationCategory(identifier: "LOCAL", serverIdentifier: "gone", isServerControlled: false)
        try database.write { db in
            try category.save(db)
        }

        XCTAssertNoThrow(try hang(manager.cleanup(definitions: [
            .orphanReassign(
                recordType: NotificationCategory.self,
                serverIdentifierColumnName: DatabaseTables.NotificationCategory.serverIdentifier.rawValue
            ),
        ])))

        let categories = try database.read { try NotificationCategory.fetchAll($0) }
        XCTAssertEqual(categories.map(\.serverIdentifier), ["gone"])
    }

    func testFailingCleanupDefinitionRejects() {
        struct CleanupFailure: Error {}

        let promise = manager.cleanup(definitions: [
            .init(cleanup: { _, _ in throw CleanupFailure() }),
        ])

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertTrue(error is CleanupFailure)
        }
    }

    func testDefaultFetchDefinitions() {
        XCTAssertEqual(LegacyModelManager.FetchDefinition.defaults.count, 1)
    }

    func testDefaultSubscribeDefinitionSubscribesToStates() {
        let definitions = LegacyModelManager.SubscribeDefinition.defaults
        XCTAssertEqual(definitions.count, 1)

        let queue = DispatchQueue(label: "LegacyModelManagerDefaultsTests.subscribe")

        let olderServer = Server.fake(identifier: "older")
        let newerServer = Server.fake(identifier: "newer") { info in
            info.version = Version(major: 2025, minor: 1)
        }

        for server in [olderServer, newerServer] {
            let connection = HAMockConnection()
            let tokens = definitions[0].subscribe(connection, server, queue, manager)
            XCTAssertEqual(tokens.count, 1)
            tokens.forEach { $0.cancel() }
        }
    }

    func testStatesDefinitionForCustomDomain() {
        let definition = LegacyModelManager.SubscribeDefinition.states(domain: "zone", type: AppZone.self)
        let connection = HAMockConnection()
        let server = Server.fake(identifier: "s1")

        let tokens = definition.subscribe(connection, server, manager.workQueue, manager)
        XCTAssertEqual(tokens.count, 1)
        tokens.forEach { $0.cancel() }
    }
}
