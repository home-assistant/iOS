import GRDB
@testable import HomeAssistant
import SFSafeSymbols
@testable import Shared
import Testing

/// The pickers behind the control widgets and the scene/automation intents, run against an
/// in-memory copy of the app's entity tables: each lists only its own domains, resolves saved picks
/// by id, and fills in the area and the domain's fallback symbol.
///
/// Serialized because every test swaps the database and the servers in `Current`.
@Suite(.serialized)
struct WidgetControlEntityQueriesTests {
    private static let serverId = "control-server"

    @Test func automationQueryResolvesPicksWithItsFallbackSymbol() async throws {
        try await withSeededDatabase {
            let query = IntentAutomationAppEntityQuery()

            let entities = try await query.entities(for: [Self.id("automation.morning"), Self.id("light.kitchen")])

            #expect(entities.map(\.entityId) == ["automation.morning"])
            let automation = try #require(entities.first)
            #expect(automation.displayString == "Morning")
            #expect(automation.serverId == Self.serverId)
            #expect(automation.serverName == "Fake Server")
            #expect(automation.iconName == SFSymbol.flowchart.rawValue)
            #expect(automation.areaName == nil)
            _ = automation.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "morn")
        }
    }

    @Test func sceneQueryResolvesPicksWithTheirOwnIcon() async throws {
        try await withSeededDatabase {
            let query = IntentSceneAppEntityQuery()

            let entities = try await query.entities(for: [Self.id("scene.movie"), Self.id("scene.missing")])

            #expect(entities.map(\.entityId) == ["scene.movie"])
            #expect(entities.first?.iconName == "mdi:movie")
            #expect(entities.first?.serverName == "Fake Server")
            _ = entities.first?.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "movie")
        }
    }

    @available(iOS 18, *)
    @Test func lightQueryCarriesTheArea() async throws {
        try await withSeededDatabase {
            let query = IntentLightAppEntityQuery()

            let entities = try await query.entities(for: [Self.id("light.kitchen"), Self.id("switch.porch")])

            #expect(entities.map(\.entityId) == ["light.kitchen"])
            let light = try #require(entities.first)
            #expect(light.areaName == "Kitchen")
            #expect(light.deviceName == nil)
            #expect(light.iconName == SFSymbol.lightbulbFill.rawValue)
            _ = light.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "kitchen")
        }
    }

    @available(iOS 18, *)
    @Test func coverQueryListsCovers() async throws {
        try await withSeededDatabase {
            let query = IntentCoverAppEntityQuery()

            let entities = try await query.entities(for: [Self.id("cover.garage"), Self.id("fan.bedroom")])

            #expect(entities.map(\.entityId) == ["cover.garage"])
            #expect(entities.first?.iconName == SFSymbol.blindsVerticalOpen.rawValue)
            _ = entities.first?.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "garage")
        }
    }

    @available(iOS 18, *)
    @Test func fanQueryListsFans() async throws {
        try await withSeededDatabase {
            let query = IntentFanAppEntityQuery()

            let entities = try await query.entities(for: [Self.id("fan.bedroom"), Self.id("cover.garage")])

            #expect(entities.map(\.entityId) == ["fan.bedroom"])
            #expect(entities.first?.iconName == SFSymbol.fan.rawValue)
            _ = entities.first?.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "bed")
        }
    }

    /// Input booleans are switches too, and a switch with no area has an empty area name rather
    /// than none.
    @available(iOS 18, *)
    @Test func switchQueryIncludesInputBooleans() async throws {
        try await withSeededDatabase {
            let query = IntentSwitchAppEntityQuery()

            let entities = try await query.entities(for: [
                Self.id("switch.porch"),
                Self.id("input_boolean.guest_mode"),
                Self.id("light.kitchen"),
            ])

            #expect(Set(entities.map(\.entityId)) == ["switch.porch", "input_boolean.guest_mode"])
            #expect(entities.allSatisfy { $0.areaName == "" })
            #expect(entities.allSatisfy { $0.iconName == SFSymbol.lightswitchOnFill.rawValue })
            _ = entities.first?.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "porch")
        }
    }

    /// The unfiltered entity picker offers every domain, and its context line can lead with the
    /// server when the result stands on its own.
    @Test func anyEntityQueryOffersEveryDomain() async throws {
        try await withSeededDatabase {
            let query = HAAppEntityAppIntentEntityQuery()

            let entities = try await query.entities(for: [
                Self.id("sensor.temperature"),
                Self.id("light.kitchen"),
                Self.id("missing.entity"),
            ])

            #expect(Set(entities.map(\.entityId)) == ["sensor.temperature", "light.kitchen"])
            let light = try #require(entities.first { $0.entityId == "light.kitchen" })
            #expect(light.areaName == "Kitchen")
            #expect(light.serverName == "Fake Server")
            #expect(light.domain == .light)
            _ = light.displayRepresentation

            _ = try await query.suggestedEntities()
            _ = try await query.entities(matching: "temp")
        }
    }

    @Test func entityContextSubtitleCanLeadWithTheServer() {
        let withServer = HAAppEntityAppIntentEntity(
            id: "s-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s",
            serverName: "Home",
            areaName: "Kitchen",
            displayString: "Kitchen light",
            iconName: "lightbulb",
            includesServerContext: true
        )
        let withoutServer = HAAppEntityAppIntentEntity(
            id: "s-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s",
            serverName: "Home",
            areaName: "Kitchen",
            displayString: "Kitchen light",
            iconName: "lightbulb"
        )

        #expect(withServer.subtitle?.contains("Home") == true)
        #expect(withServer.subtitle?.contains("Kitchen") == true)
        #expect(withoutServer.subtitle == withoutServer.contextSubtitle)
        #expect(withoutServer.subtitle?.contains("Home") != true)
        _ = withServer.displayRepresentation
        #expect(HAAppEntityAppIntentEntity.fallbackSymbolName == SFSymbol.powerCircle.rawValue)
    }

    @Test func intentItemCollectionHelperBuildsFromStoredEntities() async throws {
        try await withSeededDatabase {
            let entities = ControlEntityProvider(domains: [.light]).getEntities()
            #expect(entities.count == 1)
            #expect(entities.first?.1.map(\.entityId) == ["light.kitchen"])

            _ = makeHAEntityIntentItemCollection(entities: entities, defaultIconName: "lightbulb")
        }
    }

    // MARK: - Helpers

    private static func id(_ entityId: String) -> String {
        "\(serverId)-\(entityId)"
    }

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
        servers.add(identifier: .init(rawValue: Self.serverId), serverInfo: .fake())
        Current.servers = servers

        try await database.write { db in
            try Self.entity("automation.morning", name: "Morning").insert(db)
            try Self.entity("scene.movie", name: "Movie night", icon: "mdi:movie").insert(db)
            try Self.entity("cover.garage", name: "Garage door").insert(db)
            try Self.entity("fan.bedroom", name: "Bedroom fan").insert(db)
            try Self.entity("light.kitchen", name: "Kitchen light").insert(db)
            try Self.entity("switch.porch", name: "Porch").insert(db)
            try Self.entity("input_boolean.guest_mode", name: "Guest mode").insert(db)
            try Self.entity("sensor.temperature", name: "Temperature").insert(db)
            try AppArea(
                id: "\(Self.serverId)-kitchen",
                serverId: Self.serverId,
                areaId: "kitchen",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: ["light.kitchen"]
            ).insert(db)
        }

        try await body()
    }

    private static func entity(_ entityId: String, name: String, icon: String? = nil) -> HAAppEntity {
        HAAppEntity(
            id: id(entityId),
            entityId: entityId,
            serverId: serverId,
            domain: String(entityId.split(separator: ".")[0]),
            name: name,
            icon: icon,
            rawDeviceClass: nil
        )
    }
}
