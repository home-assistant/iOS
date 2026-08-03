import Foundation
@testable import Shared
import Testing

struct WatchGridSectionTests {
    @Test("Items with no complication stay in a single grid")
    func tilesOnly() {
        let items = [entity("light.kitchen"), entity("light.hall")]
        let sections = WatchGridSection.sections(for: items)

        #expect(sections.count == 1)
        #expect(sections.first?.id == "tiles-server-1-light.kitchen")
        guard case let .tiles(tiles) = sections[0] else {
            Issue.record("Expected a tiles section")
            return
        }
        #expect(tiles.map(\.id) == ["light.kitchen", "light.hall"])
    }

    @Test("A complication splits the surrounding tiles, keeping the configured order")
    func complicationSplitsRuns() {
        let items = [
            entity("light.kitchen"),
            complication("battery"),
            entity("light.hall"),
            entity("scene.movie"),
            complication("solar"),
        ]
        let sections = WatchGridSection.sections(for: items)

        #expect(sections.map(\.id) == [
            "tiles-server-1-light.kitchen",
            "complication-server-1-battery",
            "tiles-server-1-light.hall",
            "complication-server-1-solar",
        ])
    }

    @Test("Consecutive complications each get their own full-width row")
    func consecutiveComplications() {
        let sections = WatchGridSection.sections(for: [complication("one"), complication("two")])

        #expect(sections.map(\.id) == ["complication-server-1-one", "complication-server-1-two"])
    }

    @Test("No items produces no sections")
    func empty() {
        #expect(WatchGridSection.sections(for: []).isEmpty)
    }

    private func entity(_ id: String) -> MagicItem {
        MagicItem(id: id, serverId: "server-1", type: .entity)
    }

    private func complication(_ id: String) -> MagicItem {
        MagicItem(id: id, serverId: "server-1", type: .complication)
    }
}
