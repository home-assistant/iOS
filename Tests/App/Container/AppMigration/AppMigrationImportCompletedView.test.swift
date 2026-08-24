@testable import HomeAssistant
import Testing

struct AppMigrationImportCompletedViewTests {
    @MainActor
    @Test func success() async throws {
        guard #available(iOS 18.0, *) else { return }
        let view = AppMigrationImportCompletedView(
            summary: .init(serverCount: 2, configurationEntryCount: 17, configurationFailed: false),
            onContinue: {}
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-import-completed-success")
    }

    /// Servers landed but the configuration did not — the screen swaps its second paragraph for the
    /// one that tells the user what they have to set up again.
    @MainActor
    @Test func configurationFailed() async throws {
        guard #available(iOS 18.0, *) else { return }
        let view = AppMigrationImportCompletedView(
            summary: .init(serverCount: 2, configurationEntryCount: 0, configurationFailed: true),
            onContinue: {}
        )
        assertLightDarkSnapshots(of: view, named: "app-migration-import-completed-configuration-failed")
    }
}
