@testable import HomeAssistant
import Testing

struct AppMigrationIntroViewTests {
    /// The disclosure line pluralises on the server count, and the screen is the one users read
    /// before handing over their credentials — both counts are worth pinning.
    @MainActor
    @Test func singleServer() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationIntroView(serverCount: 1, onStart: {}, onLater: {}),
            named: "app-migration-intro-single-server"
        )
    }

    @MainActor
    @Test func multipleServers() async throws {
        guard #available(iOS 18.0, *) else { return }
        assertLightDarkSnapshots(
            of: AppMigrationIntroView(serverCount: 3, onStart: {}, onLater: {}),
            named: "app-migration-intro-multiple-servers"
        )
    }
}
