@testable import HomeAssistant
import Testing

struct AppMigrationNeedsInstallViewTests {
    @MainActor
    @Test func testUI() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationNeedsInstallView(onOpenAppStore: {}, onContinue: {}),
            named: "app-migration-needs-install"
        )
    }
}
