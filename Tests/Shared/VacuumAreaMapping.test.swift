import Foundation
@testable import Shared
import Testing

struct VacuumAreaMappingTests {
    @Test func readsMappedAreaIdsFromRegistryOptions() {
        // Shape of `config/entity_registry/get`: the mapping is area id → the vacuum's segment ids,
        // and only the keys (the areas) matter to `vacuum.clean_area`.
        let mapping = VacuumAreaMapping(attributes: [
            "entity_id": "vacuum.downstairs",
            "options": [
                "vacuum": [
                    "area_mapping": [
                        "kitchen": ["16"],
                        "living_room": ["17", "18"],
                    ],
                ],
            ],
        ])

        #expect(mapping.areaIds == ["kitchen", "living_room"])
    }

    @Test func sortsAreaIdsForStableOrdering() {
        let mapping = VacuumAreaMapping(attributes: [
            "options": ["vacuum": ["area_mapping": [
                "study": ["3"],
                "bedroom": ["1"],
                "hallway": ["2"],
            ]]],
        ])

        #expect(mapping.areaIds == ["bedroom", "hallway", "study"])
    }

    @Test func missingOptionsYieldNoAreas() {
        // A vacuum that advertises cleaning by area but has nothing mapped yet, and entries whose
        // options carry other domains only — both must read as "no areas", not as a failure.
        #expect(VacuumAreaMapping(attributes: [:]).areaIds.isEmpty)
        #expect(VacuumAreaMapping(attributes: ["options": [:]]).areaIds.isEmpty)
        #expect(VacuumAreaMapping(attributes: ["options": ["vacuum": [:]]]).areaIds.isEmpty)
        #expect(VacuumAreaMapping(attributes: ["options": ["light": ["favorite_colors": []]]]).areaIds.isEmpty)
    }

    @Test func unexpectedMappingShapeIsIgnored() {
        // Defensive: a payload whose mapping isn't a dictionary must not crash the picker.
        #expect(VacuumAreaMapping(attributes: ["options": ["vacuum": ["area_mapping": "nope"]]]).areaIds.isEmpty)
    }
}
