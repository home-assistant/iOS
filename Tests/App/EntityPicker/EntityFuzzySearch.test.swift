import Foundation
@testable import Shared
import Testing

@Suite("EntityFuzzySearch engine")
struct EntityFuzzySearchEngineTests {
    private static let keys: [FuzzyKey] = [
        FuzzyKey(name: "name", weight: 10),
        FuzzyKey(name: "deviceName", weight: 7),
        FuzzyKey(name: "areaName", weight: 6),
        FuzzyKey(name: "domainName", weight: 6),
        FuzzyKey(name: "floorName", weight: 5),
        FuzzyKey(name: "entityId", weight: 3),
    ]

    private static let documents: [FuzzyDocument] = [
        make("light.kitchen_ceiling", "Ceiling", "Kitchen Ceiling Light", "Kitchen", "Light", "Ground Floor"),
        make("light.living_room", "Living Room Lamp", "Living Room Lamp", "Living Room", "Light", "Ground Floor"),
        make("switch.kitchen_coffee", "Coffee Machine", "Coffee Maker", "Kitchen", "Switch", "Ground Floor"),
        make(
            "sensor.bedroom_temperature",
            "Bedroom Temperature",
            "Bedroom Multisensor",
            "Bedroom",
            "Sensor",
            "First Floor"
        ),
        make("climate.bedroom", "Bedroom Thermostat", "Ecobee", "Bedroom", "Climate", "First Floor"),
        make("cover.garage_door", "Garage Door", "Garage Opener", "Garage", "Cover", "Ground Floor"),
        make("light.office_desk", "Desk Lamp", "Office Desk Light", "Office", "Light", "First Floor"),
        make(
            "media_player.living_room_tv",
            "Living Room TV",
            "Samsung TV",
            "Living Room",
            "Media player",
            "Ground Floor"
        ),
        make("light.bathroom", "Bathroom", "Bathroom Light", "Bathroom", "Light", "First Floor"),
        make("fan.bedroom_ceiling", "Ceiling Fan", "Bedroom Fan", "Bedroom", "Fan", "First Floor"),
        make("sensor.salao_temperature", "Salão Temperature", "Salão Sensor", "Salão", "Sensor", "Rés do Chão"),
        make("lock.front_door", "Front Door Lock", "August Lock", "Entrance", "Lock", "Ground Floor"),
        make(
            "light.kitchen_under_cabinet",
            "Under Cabinet",
            "Kitchen Under Cabinet LED",
            "Kitchen",
            "Light",
            "Ground Floor"
        ),
        make("scene.movie_night", "Movie Night", nil, nil, "Scene", nil),
        make("automation.morning_routine", "Morning Routine", nil, nil, "Automation", nil),
    ]

    private static func make(
        _ id: String,
        _ name: String,
        _ device: String?,
        _ area: String?,
        _ domain: String,
        _ floor: String?
    ) -> FuzzyDocument {
        FuzzyDocument(id: id, fieldValues: [name, device, area, domain, floor, id])
    }

    private func search(_ query: String) -> [String] {
        let searcher = FuzzySearcher(keys: Self.keys)
        return searcher.search(query, in: Self.documents).map { Self.documents[$0].id }
    }

    @Test("Exact single-term matches across fields, ranked by relevance")
    func exactMatches() {
        #expect(search("kitchen") == [
            "light.kitchen_ceiling",
            "light.kitchen_under_cabinet",
            "switch.kitchen_coffee",
        ])
        #expect(search("ceiling") == ["light.kitchen_ceiling", "fan.bedroom_ceiling"])
        #expect(search("thermostat") == ["climate.bedroom"])
    }

    @Test("Typos are tolerated (fuzzy matching)")
    func typoTolerance() {
        #expect(search("kithen") == [
            "light.kitchen_ceiling",
            "light.kitchen_under_cabinet",
            "switch.kitchen_coffee",
        ])
        #expect(search("coffe") == ["switch.kitchen_coffee"])
    }

    @Test("Diacritics are ignored in both directions")
    func diacriticsInsensitive() {
        #expect(search("salao") == ["sensor.salao_temperature"])
        #expect(search("salão") == ["sensor.salao_temperature"])
    }

    @Test("Spaceless queries still match multi-word fields")
    func spacelessQuery() {
        #expect(search("livingroom") == ["light.living_room", "media_player.living_room_tv"])
    }

    @Test("Multi-term queries require every term to match some field")
    func multiTermAndSemantics() {
        #expect(search("living room") == ["light.living_room", "media_player.living_room_tv"])
        #expect(search("garage door") == ["cover.garage_door"])
        #expect(search("bedroom light").isEmpty)
    }

    @Test("Device, area, floor and domain names are searchable")
    func nonNameFields() {
        #expect(search("samsung") == ["media_player.living_room_tv"])
        #expect(search("entrance") == ["lock.front_door"])
        #expect(search("cabinet") == ["light.kitchen_under_cabinet"])
    }

    @Test("Unmatched queries return nothing")
    func noMatch() {
        #expect(search("xyzzy").isEmpty)
    }

    @Test("Empty query returns every document in original order")
    func emptyQuery() {
        #expect(search("") == Self.documents.map(\.id))
        #expect(search("   ") == Self.documents.map(\.id))
    }
}
