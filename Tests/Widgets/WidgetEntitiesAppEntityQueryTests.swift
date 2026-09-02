import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// The entity picker behind the entities widget configuration, run against an in-memory copy of
/// the app's entity tables.
///
/// Serialized because every test swaps the database and the servers in `Current`.
@Suite(.serialized)
struct WidgetEntitiesAppEntityQueryTests {
    /// Saved picks come back in the order they were saved, which is the order the widget draws.
    @available(iOS 17, *)
    @Test func savedPicksResolveInSavedOrder() async throws {
        try await withSeededDatabase {
            let query = WidgetEntitiesAppEntityQuery()

            let entities = try await query.entities(for: ["A-sensor.temperature", "A-light.kitchen", "A-missing"])

            #expect(entities.map(\.id) == ["A-sensor.temperature", "A-light.kitchen"])
            #expect(entities.first?.displayString == "Temperature")
        }
    }

    /// Without a search the picker lists each server's entities by name, with the area the entity
    /// belongs to on its context line — and the entities that have no area or device to show, whose
    /// context line would only repeat their id, after all of the ones that do.
    @available(iOS 17, *)
    @Test func entitiesAreListedByNameWithTheirAreaAndContextlessOnesLast() async throws {
        try await withSeededDatabase {
            let query = WidgetEntitiesAppEntityQuery()

            let perServer = query.entitiesPerServer()

            #expect(perServer.map(\.0.identifier.rawValue) == ["A", "B"])
            #expect(perServer[0].1.map(\.displayString) == ["Kitchen light", "Temperature", "Porch"])
            #expect(perServer[0].1.first?.areaName == "Kitchen")
            #expect(perServer[0].1.first?.contextSubtitle?.contains("Kitchen") == true)
            #expect(perServer[0].1.last?.hasContext == false)
            #expect(perServer[1].1.map(\.entityId) == ["light.office"])
        }
    }

    /// A search narrows the list to what matches.
    @available(iOS 17, *)
    @Test func searchNarrowsTheList() async throws {
        try await withSeededDatabase {
            let query = WidgetEntitiesAppEntityQuery()

            let perServer = query.entitiesPerServer(matching: "kitchen")

            #expect(perServer[0].1.first?.entityId == "light.kitchen")
            #expect(perServer[0].1.count < 3)
        }
    }

    /// The App Intents entry points wrap the same listing, grouping every server under its name
    /// when the configuration has not named one.
    @available(iOS 17, *)
    @Test func intentEntryPointsOfferEveryServer() async throws {
        try await withSeededDatabase {
            let query = WidgetEntitiesAppEntityQuery()

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "porch")
        }
    }

    /// A pick maps onto the item the widget renders and acts on. With no area or device to show,
    /// its context line falls back to the entity id, and its row carries no image: rendering one
    /// per row is more than the widget extension's memory allows.
    @available(iOS 17, *)
    @Test func pickBecomesAMagicItem() {
        let pick = WidgetEntitiesAppEntity(
            id: "A-light.kitchen",
            entityId: "light.kitchen",
            serverId: "A",
            displayString: "Kitchen light"
        )

        #expect(pick.magicItem == MagicItem(id: "light.kitchen", serverId: "A", type: .entity))
        #expect(pick.contextSubtitle == "light.kitchen")
        #expect(!pick.hasContext)
        #expect(pick.displayRepresentation.image == nil)
    }

    /// Two servers, "A" with three entities (two in areas) and "B" with one, in an in-memory
    /// database that stands in for the app's for the duration of `body`.
    private func withSeededDatabase(_ body: () async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        let database = try DatabaseQueue(path: ":memory:")
        try HAppEntityTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        try DisplayEntityRegistryTable().createIfNeeded(database: database)
        try AppDeviceRegistryTable().createIfNeeded(database: database)
        Current.database = { database }

        let servers = FakeServerManager()
        servers.add(identifier: .init(rawValue: "A"), serverInfo: .fake())
        servers.add(identifier: .init(rawValue: "B"), serverInfo: .fake())
        Current.servers = servers

        try await database.write { db in
            try Self.entity("A", "sensor.temperature", name: "Temperature").insert(db)
            try Self.entity("A", "light.kitchen", name: "Kitchen light").insert(db)
            try Self.entity("A", "switch.porch", name: "Porch").insert(db)
            try Self.entity("B", "light.office", name: "Office light").insert(db)
            try AppArea(
                id: "A-kitchen",
                serverId: "A",
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: ["light.kitchen"]
            ).insert(db)
            try AppArea(
                id: "A-living_room",
                serverId: "A",
                areaId: "living_room",
                name: "Living room",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: ["sensor.temperature"]
            ).insert(db)
        }

        try await body()
    }

    private static func entity(_ serverId: String, _ entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
            id: "\(serverId)-\(entityId)",
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: name,
            icon: nil,
            rawDeviceClass: nil
        )
    }
}
