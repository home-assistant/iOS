import Foundation
import GRDB
@testable import Shared
import XCTest

final class AppAreaQueriesTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let database = try DatabaseQueue()
        try AppAreaTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }

        try database.write { db in
            for area in [
                Self.area("living", name: "Living room", sortOrder: 1, entities: ["light.sofa", "media_player.tv"]),
                Self.area("kitchen", name: "Kitchen", sortOrder: 0, entities: ["light.kitchen"]),
                Self.area("attic", name: "Attic", sortOrder: nil, entities: []),
                Self.area("basement", name: "basement", sortOrder: nil, entities: ["light.sofa"]),
                Self.area("office", serverId: "server-2", name: "Office", sortOrder: 0, entities: ["light.desk"]),
            ] {
                try area.insert(db)
            }
        }
    }

    override func tearDown() {
        Current.database = previousDatabase
        super.tearDown()
    }

    func testAreasOfAServerAreSortedForDisplay() throws {
        let areas = try AppArea.fetchAreas(for: "server-1")

        // Explicit order first, then the unordered ones by name, case-insensitively.
        XCTAssertEqual(areas.map(\.areaId), ["kitchen", "living", "attic", "basement"])
        XCTAssertTrue(try AppArea.fetchAreas(for: "unknown").isEmpty)
    }

    func testAllAreasAcrossServers() throws {
        let areas = try AppArea.fetchAllAreas()

        XCTAssertEqual(areas.count, 5)
        XCTAssertEqual(Set(areas.map(\.serverId)), ["server-1", "server-2"])
        XCTAssertEqual(areas.last?.areaId, "basement")
    }

    func testFetchingASingleArea() throws {
        XCTAssertEqual(try AppArea.fetchArea(id: "server-1-kitchen")?.name, "Kitchen")
        XCTAssertEqual(try AppArea.fetchArea(areaId: "office", serverId: "server-2")?.name, "Office")
        XCTAssertNil(try AppArea.fetchArea(areaId: "office", serverId: "server-1"))
    }

    func testAreasContainingAnEntity() throws {
        let areas = try AppArea.fetchAreas(containingEntity: "light.sofa", serverId: "server-1")

        XCTAssertEqual(areas.map(\.areaId), ["living", "basement"])
        XCTAssertTrue(try AppArea.fetchAreas(containingEntity: "light.desk", serverId: "server-1").isEmpty)
    }

    private static func area(
        _ areaId: String,
        serverId: String = "server-1",
        name: String,
        sortOrder: Int?,
        entities: Set<String>
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: sortOrder,
            entities: entities
        )
    }
}
