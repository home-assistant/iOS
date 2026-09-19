import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// The entity list behind "get entity state", which asks about entities rather than switching them.
///
/// Like the on/off list it offers a narrowed set — the readable domains, in rooms — while resolving
/// anything, so an id saved in a shortcut keeps working after the entity leaves that set.
@Suite(.serialized)
struct ReadableEntityAppEntityQueryTests {
    private static func makeEntity(serverId: String, entityId: String, name: String) -> HAAppEntity {
        HAAppEntity(
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
    }

    private func seed(serverId: String, entities: [HAAppEntity], inArea: Set<String>) async throws {
        try await Current.database().write { db in
            try HAAppEntity
                .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == serverId)
                .deleteAll(db)
            for entity in entities {
                try entity.insert(db)
            }
            try AppArea
                .filter(Column(DatabaseTables.AppArea.serverId.rawValue) == serverId)
                .deleteAll(db)
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: "Bathroom",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: inArea,
                floorId: nil,
                floorName: nil
            ).insert(db)
        }
    }

    private func withFakeServer(_ body: (String) async throws -> Void) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        defer { Current.servers = previous }
        Current.servers = manager
        try await body(server.identifier.rawValue)
    }

    /// A sensor is the thing people ask about most, and a room is what makes it worth naming.
    @Test func offersReadableEntitiesThatSitInARoom() async throws {
        try await withFakeServer { serverId in
            try await seed(
                serverId: serverId,
                entities: [
                    Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity"),
                    Self.makeEntity(serverId: serverId, entityId: "sensor.orphan", name: "Orphan"),
                ],
                inArea: ["sensor.humidity"]
            )

            let offered = try await ReadableEntityAppEntityQuery().suggestedEntities()
            let ids = offered.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids == ["sensor.humidity"])
        }
    }

    /// The domain and area filters are on the offered list alone: a question saved against an entity
    /// that has since left its room still names something.
    @Test func resolvesAnEntityThatIsNoLongerOffered() async throws {
        try await withFakeServer { serverId in
            let orphan = Self.makeEntity(serverId: serverId, entityId: "sensor.orphan", name: "Orphan")
            try await seed(serverId: serverId, entities: [orphan], inArea: [])

            let resolved = try await ReadableEntityAppEntityQuery().entities(for: [orphan.id])

            #expect(resolved.count == 1)
            #expect(resolved.first?.entityId == "sensor.orphan")
            #expect(resolved.first?.displayString == "Orphan")
        }
    }

    @Test func matchesOnName() async throws {
        try await withFakeServer { serverId in
            try await seed(
                serverId: serverId,
                entities: [
                    Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity"),
                    Self.makeEntity(serverId: serverId, entityId: "sensor.pressure", name: "Pressure"),
                ],
                inArea: ["sensor.humidity", "sensor.pressure"]
            )

            let matched = try await ReadableEntityAppEntityQuery().entities(matching: "humid")
            let names = matched.sections.flatMap(\.items).map(\.value.displayString)

            #expect(names.contains("Humidity"))
            #expect(!names.contains("Pressure"))
        }
    }

    /// The row a picker draws: the entity's name on top and its context underneath, with no image of
    /// its own — the glyph is the App Shortcut's, so a question's row is not mistaken for a command's.
    @Test func theRowIsTitledByTheEntityNameAndCarriesNoImage() {
        let previous = Current.servers
        defer { Current.servers = previous }
        Current.servers = FakeServerManager(initial: 1)

        let representation = ReadableEntityAppEntity(
            id: "s1-sensor.humidity",
            entityId: "sensor.humidity",
            serverId: "s1",
            serverName: "Cabin",
            areaName: "Bathroom",
            displayString: "Humidity",
            iconName: "mdi:water-percent"
        ).displayRepresentation

        #expect(String(localized: representation.title) == "Humidity")
        #expect(representation.subtitle.map { String(localized: $0) } == "Bathroom")
        #expect(representation.image == nil)
    }

    /// A row stands alone in Siri's disambiguation, where two homes can share a name.
    @Test func theContextLineNamesTheServerOnlyWhenThereIsMoreThanOne() {
        let entity = ReadableEntityAppEntity(
            id: "s1-sensor.humidity",
            entityId: "sensor.humidity",
            serverId: "s1",
            serverName: "Cabin",
            areaName: "Bathroom",
            displayString: "Humidity",
            iconName: "mdi:water-percent"
        )

        let previous = Current.servers
        defer { Current.servers = previous }

        Current.servers = FakeServerManager(initial: 1)
        #expect(entity.subtitle == "Bathroom")

        Current.servers = FakeServerManager(initial: 2)
        #expect(entity.subtitle == "Cabin • Bathroom")
    }
}
