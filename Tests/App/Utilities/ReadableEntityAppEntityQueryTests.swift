import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import Testing

/// Exercises the entity list behind "get entity state": it offers what a person would ask about,
/// and leaves out what they would not.
struct ReadableEntityAppEntityQueryTests {
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

    private func withFakeServer(_ body: (String) async throws -> Void) async throws {
        let previous = Current.servers
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        defer { Current.servers = previous }
        Current.servers = manager
        try await body(server.identifier.rawValue)
    }

    /// The three kinds nobody asks Siri about: a diagnostic reading, a configuration control, and
    /// an entity the user hid.
    @Test func leavesOutDiagnosticConfigurationAndHiddenEntities() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "sensor.temperature", name: "Temperature"),
                Self.makeEntity(serverId: serverId, entityId: "sensor.uptime", name: "Uptime", entityCategory: 1),
                Self.makeEntity(serverId: serverId, entityId: "switch.led", name: "LED", entityCategory: 2),
                Self.makeEntity(serverId: serverId, entityId: "light.hidden", name: "Hidden", isHidden: true),
            ])
            try await seedArea(
                serverId: serverId,
                name: "Kitchen",
                entities: ["sensor.temperature", "sensor.uptime", "switch.led", "light.hidden"]
            )
            let collection = try await ReadableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("sensor.temperature"))
            #expect(!ids.contains("sensor.uptime"))
            #expect(!ids.contains("switch.led"))
            #expect(!ids.contains("light.hidden"))
        }
    }

    /// An entity in no room is one nobody names out loud.
    @Test func leavesOutEntitiesWithNoArea() async throws {
        try await withFakeServer { serverId in
            try await seed(serverId: serverId, entities: [
                Self.makeEntity(serverId: serverId, entityId: "light.kitchen", name: "Kitchen"),
                Self.makeEntity(serverId: serverId, entityId: "light.orphan", name: "Orphan"),
            ])
            try await seedArea(serverId: serverId, name: "Kitchen", entities: ["light.kitchen"])
            let collection = try await ReadableEntityAppEntityQuery().suggestedEntities()
            let ids = collection.sections.flatMap(\.items).map(\.value.entityId)

            #expect(ids.contains("light.kitchen"))
            #expect(!ids.contains("light.orphan"))
        }
    }

    @Test func resolvesAndMatchesByName() async throws {
        try await withFakeServer { serverId in
            let entity = Self.makeEntity(serverId: serverId, entityId: "sensor.humidity", name: "Humidity")
            try await seed(serverId: serverId, entities: [entity])
            try await seedArea(serverId: serverId, name: "Bathroom", entities: ["sensor.humidity"])

            let resolved = try await ReadableEntityAppEntityQuery().entities(for: [entity.id])
            #expect(resolved.first?.entityId == "sensor.humidity")
            #expect(resolved.first?.displayString == "Humidity")

            let matched = try await ReadableEntityAppEntityQuery().entities(matching: "humid")
            #expect(matched.sections.flatMap(\.items).map(\.value.entityId).contains("sensor.humidity"))
        }
    }
}

/// The question itself: the entity it names, and what it reads back.
struct GetEntityStateAppIntentTests {
    private static func entity(serverId: String) -> ReadableEntityAppEntity {
        .init(
            id: "\(serverId)-sensor.humidity",
            entityId: "sensor.humidity",
            serverId: serverId,
            serverName: "Home",
            areaName: "Bathroom",
            deviceName: "Sensor",
            floorName: "Ground floor",
            displayString: "Humidity",
            iconName: "mdi:water-percent"
        )
    }

    private static func stateResponse(_ state: String) -> HAData {
        .dictionary([
            "entity_id": "sensor.humidity",
            "state": state,
            "last_changed": "2026-09-06T10:00:00.000000+00:00",
            "last_updated": "2026-09-06T10:00:00.000000+00:00",
            "attributes": ["friendly_name": "Humidity", "unit_of_measurement": "%"],
            "context": ["id": "test", "parent_id": NSNull(), "user_id": NSNull()],
        ])
    }

    private func withMockedServer(_ body: (Server, HAMockConnection) async throws -> Void) async throws {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
        }
        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.cachedApis = [server.identifier: api]
        try await body(server, connection)
    }

    @Test(.disabled("Hangs CI when a request lands after the poll"))
    func readingAStateAsksTheServerAndKeepsTheContext() async throws {
        try await withMockedServer { server, connection in
            var intent = GetEntityStateAppIntent()
            intent.entity = Self.entity(serverId: server.identifier.rawValue)

            let task = Task { try await intent.perform() }
            var waited = 0
            while connection.pendingRequests.isEmpty, waited < 300 {
                try await Task.sleep(nanoseconds: 5_000_000)
                waited += 1
            }
            for pending in connection.pendingRequests {
                pending.completion(.success(Self.stateResponse("58")))
            }
            _ = try await task.value
            #expect(!connection.pendingRequests.isEmpty)
        }
    }

    /// The state entity keeps what the question knew about the entity, so the answer can name the
    /// room without asking again.
    @Test func theStateCarriesTheEntitysContext() throws {
        let live = try HAEntity(data: Self.stateResponse("58"))
        let state = HAEntityStateAppEntity(entity: Self.entity(serverId: "s1"), state: live)

        #expect(state.name == "Humidity")
        #expect(state.entityId == "sensor.humidity")
        #expect(state.state == "58")
        #expect(state.areaName == "Bathroom")
        #expect(state.deviceName == "Sensor")
        #expect(state.floorName == "Ground floor")
        #expect(state.serverName == "Home")
        #expect(state.iconName == "mdi:water-percent")
        #expect(state.unitOfMeasurement == "%")
    }

    @Test func theEntityDescribesItself() {
        let entity = Self.entity(serverId: "s1")
        #expect(!String(describing: entity.displayRepresentation).isEmpty)
        #expect(entity.domain == .sensor)
    }
}
