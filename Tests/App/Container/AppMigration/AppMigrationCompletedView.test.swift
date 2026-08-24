@testable import HomeAssistant
import Testing

struct AppMigrationCompletedViewTests {
    @MainActor
    @Test func testUI() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationCompletedView(serverCount: 2, onDone: {}),
            named: "app-migration-completed"
        )
    }
}
