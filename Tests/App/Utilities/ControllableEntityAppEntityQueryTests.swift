import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind the spoken on/off commands: it offers the domains a command can
/// switch, in the rooms someone would name, and nothing else.
///
/// Offering and resolving are two different things here: the query narrows what is put in front of
/// someone, while `entities(for:)` reads any id back, so a saved shortcut keeps working after its
/// entity leaves the offered list.
@Suite(.serialized)
struct ControllableEntityAppEntityQueryTests {
    private static func makeEntity(
        serverId: String,
        entityId: String,
        name: String,
        entityCategory: Int? = nil,
        isHidden: Bool? = nil
    ) -> HAAppEntity {
        HAAppEntity(
            id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
            entityId: entityId,
            serverId: serverId,
            domain: entityId.components(separatedBy: ".").first ?? "",
            name: name,
            icon: nil,
            rawDeviceClass: nil,
            entityCategory: entityCategory,
            isHidden: isHidden
        )
    }

    /// Areas carry their entities, which is also how an entity inherits its device's area.
    private func seedArea(serverId: String, name: String, entities: Set<String>) async throws {
        try await Current.database().write { db in
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .deleteAll(db)
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: name,
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: entities,
                floorId: nil,
                floorName: nil
            ).insert(db)
        }
    }

    private func seed(serverId: String, entities: [HAAppEntity]) async throws {
        try await Current.database().write { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .deleteAll(db)
            for entity in entities {
                try entity.insert(db)
            }
        }
    }

    /// Points `Current` at a single fake server whose entities are the ones seeded, and restores it.
    private func withFakeServer(
        _ body: (String) async throws -> Void
    ) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        defer { Current.servers = previous }
        Current.servers = manager
        try await body(server.identifier.rawValue)
    }

    private func offered() async throws -> [ControllableEntityAppEntity] {
        try await ControllableEntityAppEntityQuery().suggestedEntities().sections.flatMap(\.items).map(\.value)
    }

    @Test func offersSwitchableDomainsAndSkipsReadOnlyOnes() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "cover.garage", name: "Garage"),
                Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity"),
                Self.makeEntity(serverId: serverId, entityId: "scene.movie", name: "Movie"),
            ])

            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["light.kitchen", "cover.garage", "sensor.humidity", "scene.movie"]
            )

            let ids = try await offered().map(\.entityId)

            #expect(ids.contains("light.kitchen"))
            // A cover is offered by the open and close command instead, where the wording matches
            // the service it calls.
            #expect(!ids.contains("cover.garage"))
            // A scene only ever activates, so it is nothing to turn off.
            #expect(!ids.contains("scene.movie"))
            // Nothing to switch on a sensor.
            #expect(!ids.contains("sensor.humidity"))
        }
    }

    @Test func resolvesEntitiesByIdentifier() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "switch.desk", name: "Desk")
            try await seed(serverId: serverId, entities: [entity])

            try await seedArea(serverId: serverId, name: "Study", entities: ["switch.desk"])

            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [entity.id])

            #expect(resolved.count == 1)
            #expect(resolved.first?.entityId == "switch.desk")
            #expect(resolved.first?.displayString == "Desk")
            #expect(resolved.first?.domain == .switch)
        }
    }

    /// Covers are not offered here, but resolution takes every id whatever offered it, which is what
    /// keeps a saved shortcut working wherever it came from.
    @Test func resolvesACoverEvenThoughItIsNotOffered() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "cover.garage", name: "Garage")
            try await seed(serverId: serverId, entities: [entity])
            try await seedArea(serverId: serverId, name: "Garage", entities: ["cover.garage"])
            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [entity.id])
            #expect(resolved.first?.entityId == "cover.garage")
        }
    }

    /// The area filter is on the offered list alone: an entity that was put in no room can still be
    /// read back, so a shortcut saved before the room was removed goes on working.
    @Test func resolvesAnEntityInNoRoomEvenThoughItIsNotOffered() async throws {
        try await withFakeServer { serverId in
            let roomless = Self.makeEntity(serverId: serverId, entityId: "light.nowhere", name: "Nowhere")
            try await seed(serverId: serverId, entities: [roomless])
            try await seedArea(serverId: serverId, name: "Kitchen", entities: [])

            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [roomless.id])

            let none = try await offered()
            #expect(resolved.first?.entityId == "light.nowhere")
            #expect(none.isEmpty)
        }
    }

    @Test func matchesOnName() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen ceiling"),
                Self.makeEntity(serverId: serverId, entityId: "light.porch", name: "Porch"),
            ])

            // Neutral area name: the search index also matches on area, and "Kitchen" there would
            // pull in the porch light too.
            try await seedArea(serverId: serverId, name: "Ground floor", entities: ["light.kitchen", "light.porch"])

            let collection = try await ControllableEntityAppEntityQuery().entities(matching: "kitchen")
            let names = collection.sections.flatMap(\.items).map(\.value.displayString)

            #expect(names.contains("Kitchen ceiling"))
            #expect(!names.contains("Porch"))
        }
    }

    /// A row stands alone in Siri's disambiguation, where two homes can share a name, so the server
    /// leads the context line once there is more than one.
    @Test func subtitleNamesTheServerOnlyWhenThereIsMoreThanOne() {
        let entity = ControllableEntityAppEntity(
            id: "s1-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s1",
            serverName: "Cabin",
            areaName: "Kitchen",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        )

        let previous = Current.servers
        defer { Current.servers = previous }

        Current.servers = FakeServerManager(initial: 1)
        #expect(entity.subtitle == "Kitchen")

        Current.servers = FakeServerManager(initial: 2)
        #expect(entity.subtitle == "Cabin • Kitchen")
    }

    /// The row a picker draws: the entity's name on top and its context underneath, with no image of
    /// its own. The glyph is left to the App Shortcut, which is the only thing that can say whether
    /// tapping the row switches the entity, dims it or asks about it.
    @Test func theRowIsTitledByTheEntityNameAndCarriesNoImage() {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: 1)

        let representation = ControllableEntityAppEntity(
            id: "s1-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s1",
            serverName: "Cabin",
            areaName: "Kitchen",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        ).displayRepresentation

        #expect(String(localized: representation.title) == "Ceiling")
        #expect(representation.subtitle.map { String(localized: $0) } == "Kitchen")
        #expect(representation.image == nil)
    }

    /// A domain the app does not model still gets a row rather than none.
    @Test func aDomainWithNoSymbolStillDrawsARow() {
        let entity = ControllableEntityAppEntity(
            id: "s1-madeup.thing",
            entityId: "madeup.thing",
            serverId: "s1",
            serverName: "Cabin",
            displayString: "Thing",
            iconName: "mdi:help"
        )

        #expect(entity.domain == nil)
        #expect(String(localized: entity.displayRepresentation.title) == "Thing")
    }

    /// An area id resolves through the same query that offered it, which is what keeps a shortcut
    /// saved against a room working.
    @Test func anAreaIdResolves() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Ceiling"),
            ])
            try await seedArea(serverId: serverId, name: "Kitchen", entities: ["light.kitchen"])

            let offeredRows = try await offered()
            let area = try #require(offeredRows.first { $0.areaTarget != nil })

            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [area.id])

            #expect(resolved.count == 1)
            #expect(resolved.first?.id == area.id)
            #expect(resolved.first?.areaTarget?.areaId == "area")
        }
    }

    /// An area id names its domain, and an id that was valid once must keep resolving: a shortcut saved
    /// against a room's thermostats still works after thermostats stop being offered by voice.
    @Test func anAreaIdOfADomainNoLongerOfferedResolves() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "climate.hall", name: "Hall"),
            ])
            try await seedArea(serverId: serverId, name: "Hall", entities: ["climate.hall"])
            let saved = AreaTarget(areaId: "area", areaName: "Hall", domain: .climate).id(serverId: serverId)

            let offeredIds = try await offered().map(\.id)
            let resolved = try await ControllableEntityAppEntityQuery().entities(for: [saved])

            #expect(!offeredIds.contains(saved))
            #expect(resolved.first?.areaTarget?.domain == .climate)
        }
    }

    /// An area is addressed by room and an entity by id, which is the whole difference between the two
    /// on the wire.
    @Test func anAreaTargetsItsRoomAndAnEntityTargetsItself() {
        let area = ControllableEntityAppEntity(
            areaTarget: .init(areaId: "kitchen", areaName: "Kitchen", domain: .light),
            serverId: "s1",
            serverName: "Cabin"
        )
        #expect(area.serviceTarget["area_id"] as? String == "kitchen")
        #expect(area.serviceTarget["entity_id"] == nil)
        #expect(area.domain == .light)

        let entity = ControllableEntityAppEntity(
            id: "s1-light.kitchen",
            entityId: "light.kitchen",
            serverId: "s1",
            serverName: "Cabin",
            displayString: "Ceiling",
            iconName: "mdi:ceiling-light"
        )
        #expect(entity.serviceTarget["entity_id"] as? String == "light.kitchen")
        #expect(entity.serviceTarget["area_id"] == nil)
        #expect(entity.domain == .light)
    }

    /// An area row names its room in the title, so it takes the server as its second line and nothing
    /// at all when there is only one.
    @Test func anAreaRowSubtitleIsTheServerOrNothing() {
        let entity = ControllableEntityAppEntity(
            areaTarget: .init(areaId: "area", areaName: "Kitchen", domain: .light),
            serverId: "s1",
            serverName: "Cabin"
        )

        let previous = Current.servers
        defer { Current.servers = previous }

        Current.servers = FakeServerManager(initial: 1)
        #expect(entity.subtitle == nil)

        Current.servers = FakeServerManager(initial: 2)
        #expect(entity.subtitle == "Cabin")
    }

    @Test func theOfferedRowsNameTheServerWhenThereIsMoreThanOne() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Ceiling"),
            ])
            try await seedArea(serverId: serverId, name: "Kitchen", entities: ["light.kitchen"])

            let single = try await offered()
            #expect(single.first(where: { $0.entityId == "light.kitchen" })?.subtitle == "Kitchen")

            // A second server, whose own entities are none of this one's business; what changes is
            // only that a row can no longer be read without saying which home it is in.
            _ = (Current.servers as? FakeServerManager)?.addFake()
            let many = try await offered()
            let subtitle = many.first(where: { $0.entityId == "light.kitchen" })?.subtitle
            #expect(subtitle?.hasSuffix("Kitchen") == true)
            #expect(subtitle != "Kitchen")
        }
    }

    @Test func skipsConfigurationDiagnosticHiddenAndRoomlessEntities() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "switch.restart", name: "Restart", entityCategory: 0),
                Self.makeEntity(serverId: serverId, entityId: "switch.secret", name: "Secret", isHidden: true),
                Self.makeEntity(serverId: serverId, entityId: "light.nowhere", name: "Nowhere"),
            ])
            // Everything but `light.nowhere` has a room.
            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["light.kitchen", "switch.restart", "switch.secret"]
            )

            let items = try await offered()

            #expect(items.filter { $0.areaTarget == nil }.map(\.entityId) == ["light.kitchen"])
            // The one light left standing also makes its room a target, and the filtered-out
            // switches take no area of their own with them.
            #expect(items.filter { $0.areaTarget != nil }.map(\.displayString) == ["Kitchen lights"])
        }
    }

    /// A room is what makes an entity worth naming out loud, whatever its domain: a group that was
    /// never put in one stays out just like a light.
    @Test func leavesOutGroupsAndLightsThatHaveNoArea() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "group.hall", name: "Hall"),
                Self.makeEntity(serverId: serverId, entityId: "group.downstairs", name: "Downstairs"),
                Self.makeEntity(serverId: serverId, entityId: "light.nowhere", name: "Nowhere"),
            ])
            try await seedArea(serverId: serverId, name: "Hall", entities: ["group.hall"])

            let ids = try await offered().map(\.entityId)

            #expect(ids.contains("group.hall"))
            #expect(!ids.contains("group.downstairs"))
            #expect(!ids.contains("light.nowhere"))
        }
    }
}
