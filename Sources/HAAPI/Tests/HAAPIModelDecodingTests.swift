import Foundation
@testable import HAAPI
import Testing

@Suite struct HAAPIModelDecodingTests {
    @Test func decodesEntityStateWithISODates() throws {
        let json = """
        {
            "entity_id": "zone.home",
            "state": "0",
            "attributes": {"radius": 100, "friendly_name": "Home"},
            "last_changed": "2026-07-16T10:00:00.123456+00:00",
            "last_updated": "2026-07-16T10:00:01+00:00"
        }
        """
        let state = try HAAPIConnection.makeDecoder().decode(HAAPIEntityState.self, from: Data(json.utf8))
        #expect(state.entityId == "zone.home")
        #expect(state.domain == "zone")
        #expect(state.state == "0")
        #expect(state.attributes["radius"] == .int(100))
        #expect(state.lastChanged != nil)
        #expect(state.lastUpdated != nil)
    }

    @Test func decodesCompressedStatesUpdate() throws {
        let json = """
        {
            "a": {
                "light.kitchen": {
                    "s": "on",
                    "a": {"brightness": 128},
                    "c": "01HZXW0000000000000000000",
                    "lc": 1720000000.5
                }
            },
            "r": ["light.removed"],
            "c": {
                "zone.home": {
                    "+": {"s": "1", "lu": 1720000001.25, "a": {"persons": ["person.bruno"]}},
                    "-": {"a": ["old_attr"]}
                }
            }
        }
        """
        let update = try HAAPIConnection.makeDecoder().decode(HAAPICompressedStatesUpdate.self, from: Data(json.utf8))
        let added = try #require(update.add?["light.kitchen"])
        #expect(added.state == "on")
        #expect(added.attributes?["brightness"] == .int(128))
        #expect(added.lastChanged == Date(timeIntervalSince1970: 1_720_000_000.5))
        #expect(update.remove == ["light.removed"])
        let diff = try #require(update.change?["zone.home"])
        #expect(diff.additions?.state == "1")
        #expect(diff.additions?.lastUpdated == Date(timeIntervalSince1970: 1_720_000_001.25))
        #expect(diff.additions?.attributes?["persons"] == .array([.string("person.bruno")]))
        #expect(diff.removals?.attributes == ["old_attr"])
    }

    @Test func decodesRegistryModels() throws {
        let areas = """
        [{"area_id": "kitchen", "name": "Kitchen", "floor_id": "ground", "icon": null, "picture": null, "aliases": []}]
        """
        let decodedAreas = try HAAPIConnection.makeDecoder().decode([HAAPIArea].self, from: Data(areas.utf8))
        #expect(decodedAreas.first?.areaId == "kitchen")
        #expect(decodedAreas.first?.floorId == "ground")

        let devices = """
        [{"id": "abc123", "area_id": "kitchen", "name": "Hue Bridge", "name_by_user": null}]
        """
        let decodedDevices = try HAAPIConnection.makeDecoder().decode(
            [HAAPIDeviceRegistryEntry].self,
            from: Data(devices.utf8)
        )
        #expect(decodedDevices.first?.id == "abc123")
        #expect(decodedDevices.first?.areaId == "kitchen")

        let pipelines = """
        {"pipelines": [{"id": "p1", "name": "Assist", "language": "en"}], "preferred_pipeline": "p1"}
        """
        let decodedPipelines = try HAAPIConnection.makeDecoder().decode(
            HAAPIAssistPipelineList.self,
            from: Data(pipelines.utf8)
        )
        #expect(decodedPipelines.pipelines.first?.id == "p1")
        #expect(decodedPipelines.preferredPipeline == "p1")
    }

    @Test func clientMessageSplatsDataAtTopLevel() throws {
        let message = ClientMessage(
            id: 5,
            type: "call_service",
            data: ["domain": "light", "service": "turn_on"]
        )
        let text = try message.encodedText()
        let object = try #require(jsonObject(in: text))
        #expect(object["id"] as? Int == 5)
        #expect(object["type"] as? String == "call_service")
        #expect(object["domain"] as? String == "light")
        #expect(object["service"] as? String == "turn_on")
    }
}
