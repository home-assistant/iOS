@testable import HomeAssistant
@testable import Shared
import Testing

// MARK: - Test Helpers

private extension AppArea {
    static func makeTest(
        name: String,
        floorId: String? = nil,
        floorName: String? = nil,
        entities: Set<String> = [],
        serverId: String = "test-server"
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(name)",
            serverId: serverId,
            areaId: name,
            name: name,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities,
            floorId: floorId,
            floorName: floorName
        )
    }
}

// MARK: - Tests

struct EntityContextSubtitleTests {
    @Test func floorIsPlacedBetweenServerAndArea() {
        let subtitle = EntityContextSubtitle.make(
            serverName: "Home",
            floorName: "Ground Floor",
            areaName: "Living Room",
            deviceName: "Thermostat",
            entityName: "Temperature",
            entityId: "sensor.temperature",
            domain: .sensor
        )
        #expect(subtitle == "Home • Ground Floor • Living Room • Thermostat")
    }

    @Test func floorIsOmittedWhenNil() {
        let subtitle = EntityContextSubtitle.make(
            floorName: nil,
            areaName: "Living Room",
            deviceName: nil,
            entityName: "Temperature",
            entityId: "sensor.temperature",
            domain: .sensor
        )
        #expect(subtitle == "Living Room")
    }

    @Test func floorIsOmittedWhenEmpty() {
        let subtitle = EntityContextSubtitle.make(
            floorName: "",
            areaName: "Living Room",
            deviceName: nil,
            entityName: "Temperature",
            entityId: "sensor.temperature",
            domain: .sensor
        )
        #expect(subtitle == "Living Room")
    }
}

struct AppAreaFloorDisambiguationTests {
    @Test func duplicatedAreaNamesDetectsCollisionsCaseAndDiacriticInsensitive() {
        let areas: [AppArea] = [
            .makeTest(name: "Bedroom", floorName: "Upstairs"),
            .makeTest(name: "bedroom ", floorName: "Downstairs"),
            .makeTest(name: "Café", floorName: "Ground"),
            .makeTest(name: "Cafe", floorName: "First"),
            .makeTest(name: "Kitchen", floorName: "Ground"),
        ]
        let duplicated = areas.duplicatedAreaNames()
        #expect(duplicated.contains("bedroom"))
        #expect(duplicated.contains("cafe"))
        #expect(!duplicated.contains("kitchen"))
    }

    @Test func disambiguatingFloorReturnedOnlyForCollidingArea() {
        let upstairsBedroom = AppArea.makeTest(name: "Bedroom", floorName: "Upstairs")
        let downstairsBedroom = AppArea.makeTest(name: "Bedroom", floorName: "Downstairs")
        let kitchen = AppArea.makeTest(name: "Kitchen", floorName: "Ground")
        let areas = [upstairsBedroom, downstairsBedroom, kitchen]

        #expect(areas.disambiguatingFloorName(for: upstairsBedroom) == "Upstairs")
        #expect(areas.disambiguatingFloorName(for: downstairsBedroom) == "Downstairs")
        // Unique name → no floor shown even though it has one.
        #expect(areas.disambiguatingFloorName(for: kitchen) == nil)
    }

    @Test func disambiguatingFloorIsNilWhenAreaHasNoFloor() {
        let bedroomA = AppArea.makeTest(name: "Bedroom", floorName: nil)
        let bedroomB = AppArea.makeTest(name: "Bedroom", floorName: nil)
        let areas = [bedroomA, bedroomB]
        #expect(areas.disambiguatingFloorName(for: bedroomA) == nil)
    }
}
