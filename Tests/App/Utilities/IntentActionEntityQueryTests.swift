@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers reading an action back from a saved shortcut.
///
/// The availability guard sits inside the test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the query is iOS 17.
@Suite(.serialized)
struct IntentActionEntityQueryTests {
    /// The server the shortcut picked isn't available to the query here, and the action was named by
    /// a device that isn't this one, so the entity is rebuilt from the identifier rather than
    /// dropped — which is what keeps a synced shortcut showing its action.
    @Test func rebuildsAnActionFromItsIdentifier() async throws {
        guard #available(iOS 17.0, *) else { return }
        let entities = try await IntentActionEntity.defaultQuery.entities(
            for: ["identifier-from-another-device::fan.turn_on"]
        )

        #expect(entities.map(\.actionId) == ["fan.turn_on"])
        #expect(entities.map(\.serverId) == ["identifier-from-another-device"])
    }
}
