@testable import Shared
import Testing

struct WatchHomeAreasModeTests {
    private func makeArea(
        areaId: String,
        serverId: String = "server1",
        entities: Set<String> = ["light.one"]
    ) -> AppArea {
        AppArea(
            id: "\(serverId)-\(areaId)",
            serverId: serverId,
            areaId: areaId,
            name: areaId.capitalized,
            aliases: [],
            picture: nil,
            icon: nil,
            sortOrder: nil,
            entities: entities
        )
    }

    @Test func hiddenWhenUserHidAreas() {
        let mode = WatchHomeAreasMode.compute(
            areas: [makeArea(areaId: "kitchen")],
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: true
        )
        #expect(mode == .hidden)
    }

    @Test func hiddenWhenThereAreNoAreas() {
        let mode = WatchHomeAreasMode.compute(
            areas: [],
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: false
        )
        #expect(mode == .hidden)
    }

    @Test func hiddenWhenNoAreaContainsWatchEntities() {
        let mode = WatchHomeAreasMode.compute(
            areas: [makeArea(areaId: "kitchen", entities: ["camera.front"])],
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: false
        )
        #expect(mode == .hidden)
    }

    @Test func inlineForFewAreasOnSingleServer() {
        let areas = (1 ... 5).map { makeArea(areaId: "area\($0)") }
        let mode = WatchHomeAreasMode.compute(
            areas: areas,
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: false
        )
        #expect(mode == .inline(areas))
    }

    @Test func inlineDropsAreasWithoutWatchEntities() {
        let populated = makeArea(areaId: "kitchen")
        let empty = makeArea(areaId: "garage", entities: ["camera.garage"])
        let mode = WatchHomeAreasMode.compute(
            areas: [populated, empty],
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: false
        )
        #expect(mode == .inline([populated]))
    }

    @Test func groupedWhenMoreAreasThanInlineLimit() {
        let areas = (1 ... 6).map { makeArea(areaId: "area\($0)") }
        let mode = WatchHomeAreasMode.compute(
            areas: areas,
            watchEntityIdsByServer: ["server1": ["light.one"]],
            hideAreas: false
        )
        #expect(mode == .grouped(serverIds: ["server1"]))
    }

    @Test func groupedWhenAreasSpanMultipleServers() {
        let mode = WatchHomeAreasMode.compute(
            areas: [
                makeArea(areaId: "kitchen", serverId: "server1"),
                makeArea(areaId: "office", serverId: "server2"),
            ],
            watchEntityIdsByServer: [
                "server1": ["light.one"],
                "server2": ["light.one"],
            ],
            hideAreas: false
        )
        #expect(mode == .grouped(serverIds: ["server1", "server2"]))
    }

    @Test func groupedIgnoresServersWithoutWatchEntities() {
        let areas = (1 ... 6).map { makeArea(areaId: "area\($0)", serverId: "server1") }
            + [makeArea(areaId: "office", serverId: "server2", entities: ["camera.office"])]
        let mode = WatchHomeAreasMode.compute(
            areas: areas,
            watchEntityIdsByServer: [
                "server1": ["light.one"],
                "server2": ["light.two"],
            ],
            hideAreas: false
        )
        #expect(mode == .grouped(serverIds: ["server1"]))
    }
}
