@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers reading a camera back from a saved shortcut.
///
/// The availability guard sits inside the test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the query is iOS 17.
@Suite(.serialized)
struct IntentCameraEntityQueryTests {
    /// The server the shortcut picked isn't available to the query here, and the camera was named by
    /// a device that isn't this one, so the entity is rebuilt from the identifier rather than
    /// dropped — which is what keeps a synced shortcut showing its camera.
    @Test func rebuildsACameraFromItsIdentifier() async throws {
        guard #available(iOS 17.0, *) else { return }
        let entities = try await IntentCameraEntity.defaultQuery.entities(
            for: ["identifier-from-another-device::camera.front_door"]
        )

        #expect(entities.map(\.entityId) == ["camera.front_door"])
        #expect(entities.map(\.serverId) == ["identifier-from-another-device"])
    }
}
