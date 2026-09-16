import AppIntents
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Serialized because every test swaps `Current.database` and `Current.servers` for its own.
@Suite(.serialized)
struct EntityControlDonationTests {
    // MARK: - Mapping a service to a command

    @Test func turnOnOffServicesMapToTheOnOffCommand() {
        #expect(command("light.kitchen", "light", "turn_on") == .turnOnOff(.on))
        #expect(command("light.kitchen", "light", "turn_off") == .turnOnOff(.off))
        #expect(command("light.kitchen", "light", "toggle") == .turnOnOff(.toggle))
        #expect(command("switch.fan", "switch", "turn_on") == .turnOnOff(.on))
    }

    @Test func homeAssistantDomainReadsAgainstTheEntityDomain() {
        #expect(command("light.kitchen", "homeassistant", "turn_off") == .turnOnOff(.off))
        #expect(command("group.downstairs", "homeassistant", "turn_on") == .turnOnOff(.on))
    }

    @Test func serviceFromAnotherDomainIsNotACommand() {
        #expect(command("light.kitchen", "switch", "turn_on") == nil)
        #expect(command("cover.garage", "light", "turn_on") == nil)
    }

    @Test func coversMapToOpenAndClose() {
        #expect(command("cover.garage", "cover", "open_cover") == .openClose(.open))
        #expect(command("cover.garage", "cover", "close_cover") == .openClose(.close))
        #expect(command("cover.garage", "cover", "stop_cover") == nil)
        #expect(command("cover.garage", "cover", "toggle") == nil)
    }

    @Test func lockingIsACommandAndUnlockingIsNot() {
        #expect(command("lock.front_door", "lock", "lock") == .lock)
        #expect(command("lock.front_door", "lock", "unlock") == nil)
    }

    @Test func domainsWithoutAVoiceCommandAreSkipped() {
        #expect(command("scene.movie", "scene", "turn_on") == nil)
        #expect(command("climate.living_room", "climate", "turn_off") == nil)
        #expect(command("script.morning", "script", "turn_on") == nil)
        #expect(command("siren.alarm", "siren", "turn_on") == nil)
        #expect(command("sensor.temperature", "homeassistant", "update_entity") == nil)
        #expect(command("not_an_entity", "light", "turn_on") == nil)
    }

    // MARK: - Donating

    @Test func aLightTurnedOnDonatesTheOnOffIntent() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "light.kitchen", serverId: serverId)

            await donation(recorder).donate(message(["light.kitchen"], "light", "turn_on"), serverId: serverId)

            let intent = try #require(recorder.intents.first as? TurnOnOffEntityAppIntent)
            #expect(recorder.intents.count == 1)
            #expect(intent.action == .on)
            #expect(intent.entity.entityId == "light.kitchen")
        }
    }

    @Test func aCoverOpenedDonatesTheOpenCloseIntent() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "cover.garage", serverId: serverId)

            await donation(recorder).donate(message(["cover.garage"], "cover", "open_cover"), serverId: serverId)

            let intent = try #require(recorder.intents.first as? OpenCloseEntityAppIntent)
            #expect(intent.action == .open)
            #expect(intent.entity.entityId == "cover.garage")
        }
    }

    @Test func aLockLockedDonatesTheLockIntent() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "lock.front_door", serverId: serverId)

            await donation(recorder).donate(message(["lock.front_door"], "lock", "lock"), serverId: serverId)

            let intent = try #require(recorder.intents.first as? LockEntityAppIntent)
            #expect(intent.entity.entityId == "lock.front_door")
        }
    }

    /// A group call reaches several entities; each gets its own donation, and one the intents have
    /// no command for is passed over rather than stopping the rest.
    @Test func everyControlledEntityIsDonatedOnItsOwn() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "light.kitchen", serverId: serverId)
            try seed(entityId: "light.hall", serverId: serverId)
            try seed(entityId: "sensor.power", serverId: serverId)

            await donation(recorder).donate(
                message(["light.kitchen", "sensor.power", "light.hall"], "homeassistant", "turn_off"),
                serverId: serverId
            )

            let entityIds = recorder.intents.compactMap { ($0 as? TurnOnOffEntityAppIntent)?.entity.entityId }
            #expect(Set(entityIds) == ["light.kitchen", "light.hall"])
            #expect(entityIds.count == 2)
        }
    }

    /// Suggesting a control is a disclosure of what the user does, so a server hidden from Siri
    /// donates nothing at all.
    @Test func aServerHiddenFromSiriDonatesNothing() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "light.kitchen", serverId: serverId)
            SiriServerExposure.setExposed(false, serverId: serverId)

            await donation(recorder).donate(message(["light.kitchen"], "light", "turn_on"), serverId: serverId)

            #expect(recorder.intents.isEmpty)
        }
    }

    /// Nothing is donated that the intent's own query could not resolve back into an entity.
    @Test func anEntityTheQueriesDoNotKnowDonatesNothing() async throws {
        try await withDatabase { serverId, recorder in
            let donation = donation(recorder)
            await donation.donate(message(["light.kitchen"], "light", "turn_on"), serverId: serverId)
            await donation.donate(message(["cover.garage"], "cover", "open_cover"), serverId: serverId)
            await donation.donate(message(["lock.front_door"], "lock", "lock"), serverId: serverId)

            #expect(recorder.intents.isEmpty)
        }
    }

    @Test func aFailedDonationIsLoggedAndDoesNotStopTheRest() async throws {
        try await withDatabase { serverId, recorder in
            try seed(entityId: "light.kitchen", serverId: serverId)
            try seed(entityId: "light.hall", serverId: serverId)
            let donation = EntityControlDonation { intent in
                recorder.intents.append(intent)
                throw URLError(.cancelled)
            }

            await donation.donate(message(["light.kitchen", "light.hall"], "light", "turn_on"), serverId: serverId)

            #expect(recorder.intents.count == 2)
        }
    }

    // MARK: - Helpers

    private final class Recorder: @unchecked Sendable {
        var intents: [any AppIntent] = []
    }

    private func command(_ entityId: String, _ domain: String, _ service: String) -> EntityControlDonation.Command? {
        EntityControlDonation.command(entityId: entityId, domain: domain, service: service)
    }

    private func message(_ entityIds: [String], _ domain: String, _ service: String) -> EntityControlMessage {
        EntityControlMessage(payload: ["entity_ids": entityIds, "domain": domain, "service": service])!
    }

    private func donation(_ recorder: Recorder) -> EntityControlDonation {
        EntityControlDonation { intent in
            recorder.intents.append(intent)
        }
    }

    private func seed(entityId: String, serverId: String) throws {
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
            let area = try AppArea.fetchOne(db, key: "\(serverId)-area")
            try AppArea(
                id: "\(serverId)-area",
                serverId: serverId,
                areaId: "area",
                name: "Kitchen",
                aliases: [],
                picture: nil,
                icon: nil,
                sortOrder: nil,
                entities: (area?.entities ?? []).union([entityId]),
                floorId: nil,
                floorName: nil
            ).insert(db, onConflict: .replace)
        }
    }

    private func withDatabase(perform work: (String, Recorder) async throws -> Void) async throws {
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

        try await work(server.identifier.rawValue, Recorder())
    }
}
