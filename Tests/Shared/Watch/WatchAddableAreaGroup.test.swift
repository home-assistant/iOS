import Foundation
import GRDB
@testable import Shared
import Testing

/// Serialized because every test swaps the global `Current.database`.
@Suite(.serialized)
struct WatchAddableAreaGroupTests {
    private func server(id: String) -> Server {
        let info = ServerInfo.fake()
        return Server(identifier: .init(rawValue: id), getter: { info }, setter: { _ in true })
    }

    private static func entity(_ entityId: String, serverId: String) -> HAAppEntity {
        .init(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: entityId,
            icon: nil,
            rawDeviceClass: nil
        )
    }

    private static func area(_ areaId: String, serverId: String, entities: Set<String>) -> AppArea {
        .init(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: areaId,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities
        )
    }

    private func withDatabase(perform work: (DatabaseQueue) throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppAreaTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

        try work(database)
    }

    @Test func groupsPopulatedAreasPerServerAndDropsEmptyServers() throws {
        try withDatabase { database in
            try database.write { db in
                try Self.entity("light.kitchen", serverId: "1").insert(db)
                try Self.area("kitchen", serverId: "1", entities: ["light.kitchen"]).insert(db)
                try Self.area("storage", serverId: "1", entities: []).insert(db)
                try Self.area("garage", serverId: "2", entities: []).insert(db)
            }

            let serverOne = server(id: "1")
            let groups = WatchAddableAreaGroup.make(servers: [serverOne, server(id: "2")])

            #expect(groups.count == 1)
            let group = try #require(groups.first)
            #expect(group.id == "1")
            #expect(group.serverId == "1")
            #expect(group.serverName == serverOne.info.name)
            #expect(group.areas.map(\.areaId) == ["kitchen"])
        }
    }

    @Test func noServersGiveNoGroups() {
        #expect(WatchAddableAreaGroup.make(servers: []).isEmpty)
    }

    @Test func memberwiseInitKeepsItsValues() {
        let group = WatchAddableAreaGroup(serverId: "s", serverName: "Home", areas: [])
        #expect(group.id == "s")
        #expect(group.serverName == "Home")
        #expect(group.areas.isEmpty)
    }
}
