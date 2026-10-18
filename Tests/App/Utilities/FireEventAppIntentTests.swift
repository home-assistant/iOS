@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers which server an event is fired at.
///
/// The availability guard sits inside the test rather than on the suite: `@Suite` cannot be applied
/// to a type marked `@available`, and the intent is iOS 17.
@Suite(.serialized)
struct FireEventAppIntentTests {
    /// An identifier resolves to nothing when no server is set up, so the event is refused rather
    /// than fired at whatever happens to be around.
    @Test func refusesWhenNoServerIsSetUp() async throws {
        guard #available(iOS 17.0, *) else { return }
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let intent = FireEventAppIntent()
        intent.server = IntentServerAppEntity(identifier: .init(rawValue: "identifier-from-another-device"))
        intent.eventName = "my_event"
        intent.eventData = "{}"

        await #expect(throws: ShortcutAppIntentError.self) {
            _ = try await intent.perform()
        }
    }
}
