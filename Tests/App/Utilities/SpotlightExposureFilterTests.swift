@testable import HomeAssistant
@testable import Shared
import Testing

/// The decisions the Spotlight index makes about the Siri opt-out, tested directly: the indexer
/// itself only ever runs from notifications and database observers.
struct SpotlightExposureFilterTests {
    @available(iOS 18.0, *)
    private func servers(_ count: Int) -> [Server] {
        let manager = FakeServerManager(initial: 0)
        return (0 ..< count).map { _ in manager.addFake() }
    }

    @Test func aHiddenServerIsLeftOutOfTheIndex() {
        guard #available(iOS 18.0, *) else { return }
        let all = servers(2)
        let hidden = all[0].identifier.rawValue
        let indexable = SpotlightEntityIndexer.indexableServers(all, hiding: [hidden])

        #expect(indexable.count == 1)
        #expect(!indexable.map(\.identifier.rawValue).contains(hidden))
    }

    @Test func nothingHiddenKeepsEveryServer() {
        guard #available(iOS 18.0, *) else { return }
        let all = servers(3)
        #expect(SpotlightEntityIndexer.indexableServers(all, hiding: []).count == all.count)
    }

    /// A stable order, so an unchanged home produces an unchanged signature.
    @Test func serversComeBackInAStableOrder() {
        guard #available(iOS 18.0, *) else { return }
        let all = servers(3)
        let once = SpotlightEntityIndexer.indexableServers(all, hiding: []).map(\.identifier.rawValue)
        let again = SpotlightEntityIndexer.indexableServers(all.reversed(), hiding: []).map(\.identifier.rawValue)
        #expect(once == again)
        #expect(once == once.sorted())
    }

    @Test func calendarsFollowTheirServer() {
        guard #available(iOS 18.0, *) else { return }
        let calendars = [
            HACalendar(
                id: "a",
                serverId: "s1",
                entityId: "calendar.one",
                name: "One",
                backgroundColor: "#fff",
                supportedFeatures: 0,
                sortOrder: 0
            ),
            HACalendar(
                id: "b",
                serverId: "s2",
                entityId: "calendar.two",
                name: "Two",
                backgroundColor: "#fff",
                supportedFeatures: 0,
                sortOrder: 1
            ),
        ]
        let kept = SpotlightEntityIndexer.indexableCalendars(calendars, hiding: ["s1"])
        #expect(kept.map(\.serverId) == ["s2"])
    }

    /// Flipping the setting has to read as a change, or the next pass skips it as unchanged.
    @Test func theSignatureChangesWithTheChoice() {
        guard #available(iOS 18.0, *) else { return }
        let none = SpotlightEntityIndexer.signaturePrefix(includesServerContext: true, hiding: [])
        let one = SpotlightEntityIndexer.signaturePrefix(includesServerContext: true, hiding: ["s1"])
        let other = SpotlightEntityIndexer.signaturePrefix(includesServerContext: true, hiding: ["s2"])

        #expect(none != one)
        #expect(one != other)
        #expect(one == SpotlightEntityIndexer.signaturePrefix(includesServerContext: true, hiding: ["s1"]))
    }

    /// The order two hidden servers arrive in must not change the signature.
    @Test func theSignatureDoesNotDependOnOrder() {
        guard #available(iOS 18.0, *) else { return }
        let a = SpotlightEntityIndexer.signaturePrefix(includesServerContext: false, hiding: ["s1", "s2"])
        let b = SpotlightEntityIndexer.signaturePrefix(includesServerContext: false, hiding: ["s2", "s1"])
        #expect(a == b)
    }
}
