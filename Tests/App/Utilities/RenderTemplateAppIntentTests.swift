@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers which server a template is rendered against.
@Suite(.serialized)
struct RenderTemplateAppIntentTests {
    /// An identifier resolves to nothing when no server is set up, so rendering is refused rather
    /// than sent to whatever happens to be around.
    @Test func refusesWhenNoServerIsSetUp() async throws {
        let previousServers = Current.servers
        defer { Current.servers = previousServers }
        Current.servers = FakeServerManager(initial: 0)

        let intent = RenderTemplateAppIntent()
        intent.server = IntentServerAppEntity(identifier: .init(rawValue: "identifier-from-another-device"))
        intent.template = "{{ now() }}"

        await #expect(throws: ShortcutAppIntentError.self) {
            _ = try await intent.perform()
        }
    }
}
