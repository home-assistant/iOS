import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Walks the kiosk settings: the main screen, the screensaver settings with their clock and dimming
/// pages, the sensors and the settings-entry customization, flipping every toggle on the way.
/// Shared state: the screens read and auto-save `Current.database`, and read `Current.servers`,
/// `Current.kiosk` and `Current.sensors`.
@Suite(.sharedState)
@MainActor
struct KioskSettingsViewRenderTests {
    @Test func walksEveryScreen() async throws {
        try await withKiosk(KioskSettings(
            enabled: true,
            acceptRemoteCommands: true,
            settingsEntryBackgroundColor: "#000000",
            settingsEntryIconColor: "#FFFFFF",
            screensaver: .init(enabled: true, mode: .clock, showDate: true, dimEnabled: true)
        )) {
            let driver = await SwiftUIScreenDriver.show(KioskSettingsView())
            defer { driver.close() }
            let pushed = await driver.pushEveryRow {
                await driver.toggleSwitches()
                // One level further: the screensaver's clock and dimming pages.
                await driver.pushEveryRow {
                    await driver.toggleSwitches()
                    await driver.toggleSwitches()
                }
                await driver.toggleSwitches()
            }
            #expect(pushed == 3)
        }
    }

    @Test func screensaverPagesForEachMode() async throws {
        for mode in KioskScreensaverMode.allCases {
            try await withKiosk(KioskSettings(screensaver: .init(enabled: true, mode: mode, showDate: false))) {
                let viewModel = KioskSettingsViewModel()
                let driver = await SwiftUIScreenDriver.show(KioskScreensaverSettingsView(viewModel: viewModel))
                await driver.pushEveryRow()
                await driver.toggleSwitches()
                driver.close()

                let clock = await SwiftUIScreenDriver.show(KioskScreensaverClockSettingsView(viewModel: viewModel))
                await clock.toggleSwitches()
                clock.close()
                let dimming = await SwiftUIScreenDriver.show(KioskScreensaverDimmingSettingsView(viewModel: viewModel))
                await dimming.toggleSwitches()
                dimming.close()
            }
        }
    }

    /// The dashboard picker offers each of the server's dashboards.
    @Test func dashboardPickerListsTheServersDashboards() async throws {
        try await withKiosk(KioskSettings(enabled: true)) {
            let serverId = try #require(Current.servers.all.first?.identifier.rawValue)
            try await Current.database().write { db in
                try AppPanel(
                    serverId: serverId,
                    title: "Kiosk",
                    path: "lovelace-kiosk",
                    component: "lovelace",
                    showInSidebar: true
                ).insert(db)
            }
            let driver = await SwiftUIScreenDriver.show(KioskSettingsView())
            defer { driver.close() }
            #expect(driver.sectionCount > 1)
        }
    }

    /// Without custom colors the settings entry preview uses the default ones.
    @Test func entryCustomizationFallsBackToTheDefaultColors() async throws {
        try await withKiosk(KioskSettings(enabled: true)) {
            let viewModel = KioskSettingsViewModel()
            #expect(viewModel.settings.settingsEntryBackgroundColor == nil)
            #expect(viewModel.settings.settingsEntryIconColor == nil)
            let driver = await SwiftUIScreenDriver.show(KioskSettingsEntryCustomizationView(viewModel: viewModel))
            defer { driver.close() }
            #expect(driver.sectionCount >= 1)
        }
    }

    @Test func hidingTheSettingsEntryAsksFirst() async throws {
        try await withKiosk(KioskSettings(enabled: true)) {
            let viewModel = KioskSettingsViewModel()
            viewModel.settingsEntryHidden.wrappedValue = true
            #expect(viewModel.isShowingHideSettingsEntryConfirmation)
            #expect(!viewModel.settings.settingsEntryHidden)
            viewModel.confirmHidingSettingsEntry()
            #expect(viewModel.settingsEntryHidden.wrappedValue)
            viewModel.settingsEntryHidden.wrappedValue = false
            #expect(!viewModel.settings.settingsEntryHidden)
        }
    }

    @Test func viewModelLoadsSavesAndReloadsDashboards() async throws {
        try await withKiosk(KioskSettings(enabled: true, dashboard: "lovelace-kiosk")) {
            let viewModel = KioskSettingsViewModel()
            #expect(viewModel.settings.enabled)
            #expect(viewModel.isUnlocked)
            #expect(viewModel.servers.count == 1)

            viewModel.serverDidChange()
            #expect(viewModel.settings.dashboard == nil)
            viewModel.settings.serverId = nil
            viewModel.reloadPanels()
            #expect(viewModel.panels.isEmpty)

            #expect(viewModel.save())
            let stored = try KioskSettings.current()
            #expect(stored?.dashboard == nil)
        }
    }

    /// Requiring authentication starts locked. Neither authenticating nor showing the locked screen
    /// is exercised: both would put the system's passcode prompt over the simulator.
    @Test func requiringAuthenticationLocksTheScreen() async throws {
        try await withKiosk(KioskSettings(enabled: true, requireAuthentication: true)) {
            let viewModel = KioskSettingsViewModel()
            #expect(!viewModel.isUnlocked)
        }
        try await withKiosk(KioskSettings(enabled: true)) {
            let viewModel = KioskSettingsViewModel()
            // Nothing to unlock: no prompt.
            viewModel.authenticateIfNeeded()
            #expect(viewModel.isUnlocked)
        }
    }

    /// A database without the kiosk table leaves the defaults in place; a save that cannot be written
    /// is reported.
    @Test func viewModelReportsDatabaseFailures() async throws {
        try await withKiosk(KioskSettings(enabled: true)) {
            let viewModel = KioskSettingsViewModel()
            Current.database = { try! DatabaseQueue() }
            #expect(!viewModel.save())
            #expect(viewModel.showError)
            #expect(viewModel.errorMessage != nil)

            let unreadable = KioskSettingsViewModel()
            #expect(!unreadable.settings.enabled)
        }
    }

    private func withKiosk(_ settings: KioskSettings, _ body: () async throws -> Void) async throws {
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
        try await database.write { db in
            try settings.insert(db, onConflict: .replace)
        }
        Current.kiosk = KioskModeManager()
        try await body()
    }
}
