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

    /// Everything that is not a cover is the one shared entity, which is what "turn this off", "what
    /// is this" and "add this to CarPlay" all take.
    @Test("Anything but a cover is named by the shared entity alone")
    func aLightIsTheSharedEntity() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "light.kitchen", serverId: serverId)

            let types = await OnscreenEntityIdentifier
                .makeAll(entityId: "light.kitchen", serverId: serverId)
                .map(\.entityType)

            #expect(types.count == 1)
            #expect(types.first == HAAppEntityAppIntentEntity.self)
        }
    }

    /// A lock is deliberately out of reach of a spoken on/off command, but the shared entity is what
    /// the question and the add-to command take, so it is still named.
    @Test("An entity no command can switch is still named")
    func anUnswitchableEntityIsStillNamed() async throws {
        guard #available(iOS 18.2, *) else { return }
        try await withDatabase { serverId in
            try seed(entityId: "lock.front_door", serverId: serverId)

            let identifier = await OnscreenEntityIdentifier.make(entityId: "lock.front_door", serverId: serverId)

            #expect(identifier?.entityType == HAAppEntityAppIntentEntity.self)
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

            #expect(types.count == 2)
            #expect(types.first == OpenableEntityAppEntity.self)
            #expect(types.contains { $0 == HAAppEntityAppIntentEntity.self })
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

            #expect(types.count == 1)
            #expect(types.first == HAAppEntityAppIntentEntity.self)
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
