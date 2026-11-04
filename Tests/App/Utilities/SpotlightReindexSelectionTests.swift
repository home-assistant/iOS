@testable import HomeAssistant
@testable import Shared
import Testing

/// Which entities a system-requested Spotlight refresh actually reindexes. Tested directly: the
/// indexer itself only runs from the system's requests, and its index is a `CSSearchableIndex`
/// it owns.
struct SpotlightReindexSelectionTests {
    private func entity(_ id: String) -> HAAppEntityAppIntentEntity {
        HAAppEntityAppIntentEntity(
            id: id,
            entityId: id,
            serverId: "s1",
            serverName: "Home",
            displayString: id,
            iconName: "power.circle"
        )
    }

    @Test func onlyTheNamedEntitiesAreReindexed() {
        guard #available(iOS 18.0, *) else { return }
        let all = [entity("light.one"), entity("light.two"), entity("switch.three")]

        let picked = SpotlightEntityIndexer.entitiesToReindex(
            from: all,
            matching: ["light.two", "switch.three"]
        )

        #expect(picked.map(\.id) == ["light.two", "switch.three"])
    }

    /// The snapshot is rebuilt from the database, so the system can name an entity that has since
    /// been removed. That is not an error, it just has nothing to reindex.
    @Test func identifiersTheSnapshotNoLongerHoldsAreDropped() {
        guard #available(iOS 18.0, *) else { return }
        let all = [entity("light.one")]

        let picked = SpotlightEntityIndexer.entitiesToReindex(
            from: all,
            matching: ["light.one", "light.deleted"]
        )

        #expect(picked.map(\.id) == ["light.one"])
    }

    @Test func namingNothingReindexesNothing() {
        guard #available(iOS 18.0, *) else { return }
        #expect(SpotlightEntityIndexer.entitiesToReindex(from: [entity("light.one")], matching: []).isEmpty)
    }

    /// A refresh of everything still goes through `reindex(reason:)`, so an empty snapshot here
    /// simply has nothing to offer rather than reporting a failure.
    @Test func anEmptySnapshotYieldsNothing() {
        guard #available(iOS 18.0, *) else { return }
        #expect(SpotlightEntityIndexer.entitiesToReindex(from: [], matching: ["light.one"]).isEmpty)
    }

    /// The snapshot's order is what the index is built from, so the selection must not reorder it
    /// to match the order the system happened to ask in.
    @Test func theSnapshotOrderIsKept() {
        guard #available(iOS 18.0, *) else { return }
        let all = [entity("a"), entity("b"), entity("c")]

        let picked = SpotlightEntityIndexer.entitiesToReindex(from: all, matching: ["c", "a"])

        #expect(picked.map(\.id) == ["a", "c"])
    }

    /// The same identifier twice is one entity, not two index entries.
    @Test func repeatedIdentifiersDoNotDuplicateEntities() {
        guard #available(iOS 18.0, *) else { return }
        let all = [entity("light.one"), entity("light.two")]

        let picked = SpotlightEntityIndexer.entitiesToReindex(
            from: all,
            matching: ["light.one", "light.one"]
        )

        #expect(picked.map(\.id) == ["light.one"])
    }
}
