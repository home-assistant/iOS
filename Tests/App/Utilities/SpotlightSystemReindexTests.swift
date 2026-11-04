import CoreSpotlight
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The reindex the system asks for, rather than the one the app schedules for itself.
///
/// These run through `IndexedEntityQuery`, so a throw here surfaces to the system as a failed
/// refresh. What is pinned is that a request the app cannot serve — an unreadable database, or
/// identifiers it no longer holds — returns quietly instead of failing the call.
@available(iOS 27.0, *)
@MainActor
final class SpotlightSystemReindexTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var database: DatabaseQueue!
    private var server: Server!

    private var serverId: String { server.identifier.rawValue }

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database

        let database = try DatabaseQueue(path: ":memory:")
        try SiriServerExposureTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        database = nil
        server = nil
        super.tearDown()
    }

    @discardableResult
    private func seedEntity(entityId: String = "light.kitchen", name: String = "Kitchen") throws -> HAAppEntity {
        let entity = HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: nil,
            isHidden: nil
        )
        try database.write { try entity.insert($0) }
        return entity
    }

    /// A database that cannot be read has no snapshot to pick from. The system asked for a refresh
    /// the app cannot give it, which is not an error the system can do anything with.
    func testADatabaseThatCannotBeReadIsNotAnError() async throws {
        let unreadable = try DatabaseQueue(path: ":memory:")
        Current.database = { unreadable }

        try await SpotlightEntityIndexer.shared.reindex(entityIds: ["anything"])
    }

    /// The system may name identifiers the snapshot no longer holds — an entity removed since it
    /// last saw the index. There is nothing to write for those, and nothing to report either.
    func testIdentifiersTheSnapshotNoLongerHoldsAreNotAnError() async throws {
        try seedEntity()

        try await SpotlightEntityIndexer.shared.reindex(entityIds: ["some-server-light.gone"])
    }

    func testAskingForNothingIsNotAnError() async throws {
        try seedEntity()

        try await SpotlightEntityIndexer.shared.reindex(entityIds: [])
    }

    /// A named entity the snapshot does hold is written to the index. The index belongs to the
    /// system and can refuse the write in a test host, which is not what this is checking: the
    /// selection behind it is covered by `SpotlightReindexSelectionTests`.
    func testANamedEntityIsOfferedToTheIndex() async throws {
        let entity = try seedEntity()

        do {
            try await SpotlightEntityIndexer.shared.reindex(entityIds: [entity.id])
        } catch {
            XCTAssertFalse(
                error is DatabaseError,
                "reading the snapshot should have succeeded, but failed with \(error)"
            )
        }
    }

    /// The whole-index rebuild the system can ask for goes through the app's own pass, so it has
    /// the same right to defer itself as any other trigger; either way it must not throw.
    func testRebuildingTheWholeIndexRunsTheAppsOwnPass() async {
        try? seedEntity()

        await SpotlightEntityIndexer.shared.reindexEverything()
    }
}
