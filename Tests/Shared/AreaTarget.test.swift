@testable import Shared
import Testing

/// The whole-area targets a spoken command offers next to its individual entities.
struct AreaTargetTests {
    private static func entity(
        _ entityId: String,
        domain: String,
        deviceClass: String? = nil
    ) -> HAAppEntity {
        HAAppEntity(
            id: "server-\(entityId)",
            entityId: entityId,
            serverId: "server",
            domain: domain,
            name: entityId,
            icon: nil,
            rawDeviceClass: deviceClass
        )
    }

    private static func area(
        _ areaId: String,
        name: String,
        entities: Set<String>,
        aliases: [String] = []
    ) -> AppArea {
        AppArea(
            id: "server-\(areaId)",
            serverId: "server",
            areaId: areaId,
            name: name,
            aliases: aliases,
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities
        )
    }

    /// One target per area and domain: a room with lights and a fan offers both, separately, so
    /// "turn on the office lights" doesn't start the fan too.
    @Test func offersOneTargetPerAreaAndDomain() {
        let entities = [
            Self.entity("light.ceiling", domain: "light"),
            Self.entity("light.desk", domain: "light"),
            Self.entity("fan.office", domain: "fan"),
        ]
        let areas = [Self.area("office", name: "Office", entities: [
            "light.ceiling", "light.desk", "fan.office",
        ])]

        let targets = entities.areaTargets(in: areas, domains: [.light, .fan])

        #expect(targets.count == 2)
        #expect(targets.map(\.domain).sorted { $0.rawValue < $1.rawValue } == [.fan, .light])
        #expect(targets.allSatisfy { $0.areaId == "office" })
    }

    /// A room with one light still gets a target: "turn on the kitchen lights" is how people speak
    /// whether the kitchen holds one lamp or five.
    @Test func offersATargetForARoomHoldingOne() {
        let entities = [Self.entity("light.kitchen", domain: "light")]
        let areas = [Self.area("kitchen", name: "Kitchen", entities: ["light.kitchen"])]

        #expect(entities.areaTargets(in: areas, domains: [.light]).count == 1)
    }

    /// A domain nothing in the room belongs to has no target, and neither does a domain the command
    /// can't act on in bulk.
    @Test func offersNothingForWhatTheRoomOrTheCommandLacks() {
        let entities = [Self.entity("light.kitchen", domain: "light")]
        let areas = [Self.area("kitchen", name: "Kitchen", entities: ["light.kitchen"])]

        #expect(entities.areaTargets(in: areas, domains: [.fan]).isEmpty)
        // A scene runs rather than switches, so a roomful of them is not a target.
        #expect(entities.areaTargets(in: areas, domains: [.scene]).isEmpty)
    }

    /// A room of curtains reads as curtains. Nobody asks Siri to close the living room "covers".
    @Test func namesCoversByWhatTheyActuallyAre() {
        let entities = [
            Self.entity("cover.left", domain: "cover", deviceClass: "curtain"),
            Self.entity("cover.right", domain: "cover", deviceClass: "curtain"),
        ]
        let areas = [Self.area("office", name: "Office", entities: ["cover.left", "cover.right"])]

        let target = entities.areaTargets(in: areas, domains: [.cover]).first
        #expect(target?.deviceClass == .curtain)
        #expect(target?.displayName.contains("curtains") == true)
    }

    /// A room whose covers disagree has no single word for them, so it keeps the domain's.
    @Test func keepsTheDomainWordForAMixedRoom() {
        let entities = [
            Self.entity("cover.left", domain: "cover", deviceClass: "curtain"),
            Self.entity("cover.garage", domain: "cover", deviceClass: "garage"),
        ]
        let areas = [Self.area("hall", name: "Hall", entities: ["cover.left", "cover.garage"])]

        let target = entities.areaTargets(in: areas, domains: [.cover]).first
        #expect(target?.deviceClass == nil)
        #expect(target?.displayName.contains("covers") == true)
    }

    /// The area's own name finds it, and so does the full target name, because someone may say
    /// either. Aliases count too: they exist so an assistant hears the room as people name it.
    @Test func matchesTheAreaTheNameAndTheAliases() {
        let target = AreaTarget(
            areaId: "office",
            areaName: "Escritório do Bruno",
            domain: .light,
            aliases: ["study"]
        )

        #expect(target.matches("Escritório do Bruno"))
        #expect(target.matches("escritorio"), "diacritics should not decide a match")
        #expect(target.matches("STUDY"), "an alias should match whatever the casing")
        #expect(target.matches("escritório do bruno lights"))
        #expect(!target.matches("kitchen"))
    }

    /// The id a saved shortcut stores. It has to stay clear of an entity's `serverId-entityId` so
    /// the two can never resolve to each other.
    @Test func theIdCannotCollideWithAnEntitys() {
        let target = AreaTarget(areaId: "office", areaName: "Office", domain: .light)
        let id = target.id(serverId: "server")

        #expect(id == "server-area:office:light")
        #expect(id != "server-light.office")
    }

    /// Two domains in one area are two targets, so their ids have to differ.
    @Test func eachDomainInAnAreaHasItsOwnId() {
        let lights = AreaTarget(areaId: "office", areaName: "Office", domain: .light)
        let fans = AreaTarget(areaId: "office", areaName: "Office", domain: .fan)

        #expect(lights.id(serverId: "server") != fans.id(serverId: "server"))
    }
}
