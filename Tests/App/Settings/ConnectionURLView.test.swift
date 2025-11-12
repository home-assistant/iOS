@testable import HomeAssistant
import Shared
import SharedTesting
import Testing

struct ConnectionURLViewTests {
    @MainActor
    @Test func internalURLView() async throws {
        let server = ServerFixture.standard
        let view = ConnectionURLView(
            server: server,
            urlType: .internal,
            onDismiss: {}
        )

        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }

    @MainActor
    @Test func externalURLView() async throws {
        let server = ServerFixture.standard
        let view = ConnectionURLView(
            server: server,
            urlType: .external,
            onDismiss: {}
        )

        assertLightDarkSnapshots(of: view, drawHierarchyInKeyWindow: true)
    }
}
