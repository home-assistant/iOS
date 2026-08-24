@testable import HomeAssistant
import Testing

struct AppMigrationImportFailureViewTests {
    @MainActor
    @Test func testUI() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationImportFailureView(
                message: "This link was written by a newer version of the app.",
                onDismiss: {}
            ),
            named: "app-migration-import-failure"
        )
    }
}
