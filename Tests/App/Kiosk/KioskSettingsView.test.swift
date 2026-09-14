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

    @available(iOS 18, *)
    @MainActor
    @Test func settingsSearchIndexesTheConfirmationRowWhileItIsShown() throws {
        try withKiosk(settings: KioskSettings(acceptRemoteCommands: true)) {
            let titles = KioskSettingsView.settingsSearchEntries.map(\.title)
            #expect(titles.contains(L10n.Kiosk.CommandConfirmation.title))
        }
    }

    @MainActor
    @Test func settingsSearchSkipsTheConfirmationRowWhileItIsHidden() throws {
        // Search must not advertise Kiosk for a row the screen does not show.
        try withKiosk(settings: KioskSettings(acceptRemoteCommands: false)) {
            let titles = KioskSettingsView.settingsSearchEntries.map(\.title)
            #expect(!titles.contains(L10n.Kiosk.CommandConfirmation.title))
            #expect(titles.contains(L10n.Kiosk.AcceptRemoteCommands.title))
        }
    }

    /// Points `Current` at a fresh in-memory database holding `settings`, so the screen's view model
    /// and the settings search read them instead of whatever the shared test database happens to carry.
    @MainActor
    private func withKiosk(settings: KioskSettings, _ body: () throws -> Void) throws {
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousSensors = Current.sensors
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.kiosk = previousKiosk
            Current.sensors = previousSensors
            Current.servers = previousServers
        }

        Current.sensors = SensorContainer()
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
        Current.kiosk = KioskModeManager()

        try body()
    }
}
