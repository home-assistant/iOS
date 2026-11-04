@testable import HomeAssistant

import Shared
import Testing

/// Covers the include/exclude domain rules the commonly-used-entities widget configuration carries.
struct WidgetDomainFilterTests {
    private static let entities = [
        "light.kitchen",
        "switch.desk_lamp",
        "media_player.living_room",
        "sensor.outside_temperature",
    ]

    @Test func emptyFilterKeepsEveryEntity() {
        let filter = WidgetDomainFilter()
        #expect(filter.isEmpty)
        #expect(filter.filter(entityIds: Self.entities) == Self.entities)
    }

    @Test func includeListKeepsOnlyTheSelectedDomains() {
        let filter = WidgetDomainFilter(includedDomains: [Domain.light.rawValue, Domain.switch.rawValue])
        #expect(filter.filter(entityIds: Self.entities) == ["light.kitchen", "switch.desk_lamp"])
    }

    @Test func excludeListDropsOnlyTheSelectedDomains() {
        let filter = WidgetDomainFilter(excludedDomains: [Domain.sensor.rawValue, Domain.mediaPlayer.rawValue])
        #expect(filter.filter(entityIds: Self.entities) == ["light.kitchen", "switch.desk_lamp"])
    }

    /// Both lists apply, and the exclude list wins on a domain named in both.
    @Test func excludeListAppliesOnTopOfTheIncludeList() {
        let filter = WidgetDomainFilter(
            includedDomains: [Domain.light.rawValue, Domain.switch.rawValue],
            excludedDomains: [Domain.switch.rawValue]
        )
        #expect(filter.filter(entityIds: Self.entities) == ["light.kitchen"])
    }

    /// A domain the app does not model still filters predictably instead of slipping through.
    @Test func unknownDomainFollowsTheSameRules() {
        let entities = Self.entities + ["water_heater_group.boilers"]
        #expect(WidgetDomainFilter(includedDomains: [Domain.light.rawValue]).filter(entityIds: entities) == [
            "light.kitchen",
        ])
        let excluding = WidgetDomainFilter(excludedDomains: ["water_heater_group"])
        #expect(excluding.filter(entityIds: entities) == Self.entities)
    }

    /// The order the prediction returns is what ranks the tiles, so filtering must not reshuffle it.
    @Test func filteringKeepsThePredictionOrder() {
        let filter = WidgetDomainFilter(excludedDomains: [Domain.switch.rawValue])
        #expect(filter.filter(entityIds: Self.entities) == [
            "light.kitchen",
            "media_player.living_room",
            "sensor.outside_temperature",
        ])
    }
}
