import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct KioskSettingsViewTests {
    @MainActor
    @Test func kioskSettingsScreenShowsCommandConfirmationToggle() throws {
        try withKiosk(settings: KioskSettings(enabled: true, acceptRemoteCommands: true)) {
            assertLightDarkSnapshots(
                of: NavigationView { KioskSettingsView() },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @MainActor
    @Test func kioskSettingsScreenHidesCommandConfirmationToggleWhenRemoteCommandsAreRefused() throws {
        // Nothing runs remotely, so there is no confirmation to configure: the row goes away with it.
        try withKiosk(settings: KioskSettings(enabled: true, acceptRemoteCommands: false)) {
            assertLightDarkSnapshots(
                of: NavigationView { KioskSettingsView() },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    /// Points `Current` at a fresh in-memory database holding `settings`, so the screen's view model
    /// loads them instead of whatever the shared test database happens to carry.
    @MainActor
    private func withKiosk(settings: KioskSettings, _ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        Current.servers = FakeServerManager(initial: 1)
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }

        var settings = settings
        settings.serverId = Current.servers.all.first?.identifier.rawValue
        try database.write { db in
            try settings.insert(db, onConflict: .replace)
        }

        try body()
    }
}
