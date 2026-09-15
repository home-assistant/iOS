import AppIntents
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// The availability guard sits inside each test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`.
@Suite(.serialized)
struct OnscreenEntityIdentifierTests {
    /// A cover leads with the type that opens and closes it, because the single identifier an activity
    /// can carry is the first one, and "open this" is how a cover is asked for.
    @Test("A cover leads with the type the open and close command takes")
    func aCoverLeadsWithOpenable() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "cover.garage", serverId: serverId)

            let identifier = await OnscreenEntityIdentifier.make(entityId: "cover.garage", serverId: serverId)

            #expect(identifier?.entityType == OpenableEntityAppEntity.self)
            #expect(identifier?.identifier == ServerEntity.uniqueId(serverId: serverId, entityId: "cover.garage"))
        }
    }

    /// "Turn this off" is what someone says to a switch, so the type that command takes leads; the
    /// shared type follows for "add this to CarPlay", and the question's type after it.
    @Test("A switch leads with the type the on and off command takes")
    func aSwitchLeadsWithControllable() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "switch.desk", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "switch.desk", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == ControllableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
            #expect(types.contains { $0 == ReadableEntityAppEntity.self })
        }
    }

    /// Nothing switches a sensor, so the question is the only thing to say to one and its type leads.
    @Test("A sensor leads with the type the question takes")
    func aSensorLeadsWithReadable() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "sensor.humidity", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "sensor.humidity", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == ReadableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
            #expect(!types.contains { $0 == ControllableEntityAppEntity.self })
        }
    }

    /// "Turn this off" is the common ask for a light, so that command's type leads; "dim this" takes
    /// the dimming type, which follows so that it binds too.
    @Test("A light leads with the on and off type and also answers to the dimming type")
    func aLightLeadsWithControllable() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "light.kitchen", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "light.kitchen", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == ControllableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
            #expect(types.contains { $0 == DimmableLightAppEntity.self })
        }
    }

    /// The dimming type's query leaves out a light in no room, but the on/off and shared types resolve
    /// every id, so the light on screen can still be turned off or added somewhere.
    @Test("A light in no room keeps the on and off type and loses the dimming type")
    func aLightInNoRoomKeepsTheCommandType() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "light.kitchen", serverId: serverId, inAnArea: false)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "light.kitchen", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == ControllableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
            #expect(!types.contains { $0 == DimmableLightAppEntity.self })
        }
    }

    /// The shared type leads so that "what is this" and the add-to command keep working where the
    /// activity is all the system reads; the lock command's own type follows for "lock this".
    @Test("A lock leads with the shared entity and also answers to the lock type")
    func aLockIsNamedTwiceSharedFirst() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "lock.front_door", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "lock.front_door", serverId: serverId)
                .map(\.entityType)

            #expect(types.count == 2)
            #expect(types.first == HAAppEntityAppIntentEntity.self)
            #expect(types.contains { $0 == LockAppEntity.self })
        }
    }

    /// Same shape for a thermostat: shared first, then the type "set this to 21" takes.
    @Test("A thermostat leads with the shared entity and also answers to the thermostat type")
    func aThermostatIsNamedTwiceSharedFirst() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "climate.hall", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "climate.hall", serverId: serverId)
                .map(\.entityType)

            #expect(types.count == 2)
            #expect(types.first == HAAppEntityAppIntentEntity.self)
            #expect(types.contains { $0 == ThermostatAppEntity.self })
        }
    }

    /// The reason a cover is named twice: "open this" takes the cover type and "add this to CarPlay"
    /// takes the shared one, and a command binds to the identifier whose type its parameter takes.
    @Test("A cover is named by both the cover type and the shared one")
    func aCoverIsNamedTwice() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "cover.garage", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "cover.garage", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == OpenableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
            // Nothing "turns off" a blind, so the on/off type is not among them.
            #expect(!types.contains { $0 == ControllableEntityAppEntity.self })
        }
    }

    /// The shared query covers every domain and every entity, so a cover the open and close list
    /// leaves out can still be added to the watch or CarPlay from the dialog showing it.
    @Test("A cover in no room keeps the shared entity and loses the cover type")
    func aCoverInNoRoomKeepsTheSharedEntity() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "cover.garage", serverId: serverId, inAnArea: false)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "cover.garage", serverId: serverId)
                .map(\.entityType)

            #expect(types.first == HAAppEntityAppIntentEntity.self)
            #expect(!types.contains { $0 == OpenableEntityAppEntity.self })
        }
    }

    /// Saying what someone is looking at is a stronger disclosure than listing what they could reach,
    /// so hiding a server from Siri has to hide the entity on screen too.
    @Test("A server hidden from Siri publishes nothing")
    func hiddenServerPublishesNothing() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "light.kitchen", serverId: serverId)
            SiriServerExposure.setExposed(false, serverId: serverId)

            let identifier = await OnscreenEntityIdentifier.make(entityId: "light.kitchen", serverId: serverId)
            #expect(identifier == nil)
        }
    }

    @Test("Something that is not an entity id publishes nothing")
    func aNonEntityPublishesNothing() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            let identifiers = await OnscreenEntityIdentifier.makeAll(entityId: "not-an-entity", serverId: serverId)
            #expect(identifiers.isEmpty)
        }
    }

    private func seed(entityId: String, serverId: String, inAnArea: Bool = true) throws {
        try Current.database().write { db in
            try HAAppEntity(
                id: ServerEntity.uniqueId(serverId: serverId, entityId: entityId),
                entityId: entityId,
                serverId: serverId,
                domain: entityId.components(separatedBy: ".").first ?? "",
                name: "Something",
                icon: nil,
                rawDeviceClass: nil
            ).insert(db, onConflict: .replace)
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: inAnArea ? [entityId] : [],
                floorId: nil,
                floorName: nil
            ).insert(db, onConflict: .replace)
        }
    }

    private func withDatabase(perform work: (String) async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let database = try DatabaseQueue(path: ":memory:")

        try SiriServerExposureTable().createIfNeeded(database: database)
        try HAppEntityTable().createIfNeeded(database: database)
        try AppAreaTable().createIfNeeded(database: database)
        Current.database = { database }

        let manager = FakeServerManager(initial: 0)
        let server = manager.addFake()
        Current.servers = manager

        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        try await work(server.identifier.rawValue)
    }
}
