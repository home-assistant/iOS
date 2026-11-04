import Foundation
import HAKit
@testable import Shared
import Testing

@Suite("HAAreasRegistryResponse Tests")
struct HAAreasRegistryResponseTests {
    @Test("Decodes floor_id when present")
    func decodesFloorId() throws {
        let data = HAData(value: [
            "aliases": [String](),
            "area_id": "living_room",
            "name": "Living Room",
            "floor_id": "ground_floor",
        ])

        let area = try HAAreasRegistryResponse(data: data)

        #expect(area.areaId == "living_room")
        #expect(area.name == "Living Room")
        #expect(area.floorId == "ground_floor")
    }

    @Test("floorId is nil when absent")
    func floorIdNilWhenAbsent() throws {
        let data = HAData(value: [
            "aliases": [String](),
            "area_id": "garden",
            "name": "Garden",
        ])

        let area = try HAAreasRegistryResponse(data: data)

        #expect(area.floorId == nil)
    }
}
