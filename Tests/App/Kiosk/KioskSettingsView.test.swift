import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

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

    // The hidden-elements row only earns its place once the switch above it is on, since the choice
    // has no effect until then.
    @MainActor
    @Test func kioskSettingsScreenShowsTheHiddenElementsRowWhileTheSwitchIsOn() throws {
        try withKiosk(settings: KioskSettings(enabled: true, removeHeaderAndSidebar: true)) {
            render(NavigationView { KioskSettingsView() })
        }
    }

    @available(iOS 18, *)
    @MainActor
    @Test func settingsSearchIndexesTheHiddenElementsRowWhileItIsShown() throws {
        try withKiosk(settings: KioskSettings(removeHeaderAndSidebar: true)) {
            let titles = KioskSettingsView.settingsSearchEntries.map(\.title)
            #expect(titles.contains(L10n.Kiosk.HiddenElements.title))
        }
    }

    @MainActor
    @Test func settingsSearchSkipsTheHiddenElementsRowWhileItIsHidden() throws {
        try withKiosk(settings: KioskSettings(removeHeaderAndSidebar: false)) {
            let titles = KioskSettingsView.settingsSearchEntries.map(\.title)
            #expect(!titles.contains(L10n.Kiosk.HiddenElements.title))
        }
    }

    /// Lays the view out in a window, which is what makes SwiftUI evaluate the body.
    ///
    /// Deliberately never becomes the key window: the snapshot helpers above draw into whatever
    /// window is key, so stealing it here would reach into them.
    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
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
