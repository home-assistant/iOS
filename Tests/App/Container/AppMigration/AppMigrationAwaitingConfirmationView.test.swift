@testable import HomeAssistant
import Testing

struct AppMigrationAwaitingConfirmationViewTests {
    @MainActor
    @Test func testUI() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationAwaitingConfirmationView(onOpenAgain: {}, onLater: {}),
            named: "app-migration-awaiting"
        )
    }
}
