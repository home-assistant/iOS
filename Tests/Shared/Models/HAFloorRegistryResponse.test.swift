import Foundation
import HAKit
@testable import Shared
import Testing

@Suite("HAFloorRegistryResponse Tests")
struct HAFloorRegistryResponseTests {
    @Test("Decodes all fields from a full payload")
    func decodeFullPayload() throws {
        let data = HAData(value: [
            "aliases": ["main floor", "downstairs"],
            "floor_id": "ground_floor",
            "name": "Ground Floor",
            "level": 0,
            "icon": "mdi:home-floor-0",
        ])

        let floor = try HAFloorRegistryResponse(data: data)

        #expect(floor.aliases == ["main floor", "downstairs"])
        #expect(floor.floorId == "ground_floor")
        #expect(floor.name == "Ground Floor")
        #expect(floor.level == 0)
        #expect(floor.icon == "mdi:home-floor-0")
    }

    @Test("Decodes when optional level and icon are absent")
    func decodeWithoutOptionalFields() throws {
        let data = HAData(value: [
            "aliases": [String](),
            "floor_id": "first_floor",
            "name": "First Floor",
        ])

        let floor = try HAFloorRegistryResponse(data: data)

        #expect(floor.aliases.isEmpty)
        #expect(floor.floorId == "first_floor")
        #expect(floor.name == "First Floor")
        #expect(floor.level == nil)
        #expect(floor.icon == nil)
    }

    @Test("Throws when a required field is missing")
    func throwsWhenRequiredFieldMissing() {
        let data = HAData(value: [
            "aliases": [String](),
            "name": "Orphan Floor",
        ])

        #expect(throws: (any Error).self) {
            _ = try HAFloorRegistryResponse(data: data)
        }
    }
}
