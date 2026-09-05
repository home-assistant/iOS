@testable import HomeAssistant
import Testing

struct AppMigrationFailureViewTests {
    @MainActor
    @Test func testUI() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationFailureView(
                message: "The new app could not be reached.",
                onRetry: {},
                onLater: {}
            ),
            named: "app-migration-failure"
        )
    }
}
