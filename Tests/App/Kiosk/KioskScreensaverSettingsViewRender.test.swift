import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the kiosk screensaver settings screens out from stored settings, so SwiftUI evaluates every
/// row each screen shows for that configuration.
///
/// The settings are stored before the view model is created and never changed afterwards: the view
/// model saves every change on the next main-queue turn, which must not outlive the in-memory
/// database used here.
@MainActor
@Suite(.serialized)
struct KioskScreensaverSettingsViewRenderTests {
    @Test func screensaverScreenInClockMode() throws {
        try withViewModel(screensaver: KioskScreensaverSettings(enabled: true, mode: .clock)) { viewModel in
            #expect(viewModel.settings.screensaver.mode == .clock)
            render(KioskScreensaverSettingsView(viewModel: viewModel))
        }
    }

    @Test func screensaverScreenInDimMode() throws {
        try withViewModel(screensaver: KioskScreensaverSettings(enabled: false, mode: .dim)) { viewModel in
            #expect(viewModel.settings.screensaver.mode == .dim)
            render(KioskScreensaverSettingsView(viewModel: viewModel))
        }
    }

    @Test func clockScreenWithAndWithoutTheDate() throws {
        try withViewModel(screensaver: KioskScreensaverSettings(showDate: true, showSeconds: true)) { viewModel in
            #expect(viewModel.settings.screensaver.showDate)
            render(KioskScreensaverClockSettingsView(viewModel: viewModel))
        }
        try withViewModel(screensaver: KioskScreensaverSettings(showDate: false)) { viewModel in
            #expect(!viewModel.settings.screensaver.showDate)
            render(KioskScreensaverClockSettingsView(viewModel: viewModel))
        }
    }

    @Test func dimmingScreenWithAndWithoutDimming() throws {
        try withViewModel(screensaver: KioskScreensaverSettings(dimEnabled: true, dimLevel: 0.3)) { viewModel in
            #expect(viewModel.settings.screensaver.dimEnabled)
            render(KioskScreensaverDimmingSettingsView(viewModel: viewModel))
        }
        try withViewModel(screensaver: KioskScreensaverSettings(dimEnabled: false)) { viewModel in
            #expect(!viewModel.settings.screensaver.dimEnabled)
            render(KioskScreensaverDimmingSettingsView(viewModel: viewModel))
        }
    }

    @Test func settingsEntryCustomizationWithDefaultAndStoredColors() throws {
        try withViewModel(screensaver: KioskScreensaverSettings()) { viewModel in
            #expect(viewModel.settings.settingsEntryBackgroundColor == nil)
            render(KioskSettingsEntryCustomizationView(viewModel: viewModel))
        }
        try withViewModel(
            screensaver: KioskScreensaverSettings(),
            backgroundColor: "#FF0000",
            iconColor: "#00FF00"
        ) { viewModel in
            #expect(viewModel.settings.settingsEntryBackgroundColor == "#FF0000")
            #expect(viewModel.settings.settingsEntryIconColor == "#00FF00")
            render(KioskSettingsEntryCustomizationView(viewModel: viewModel))
        }
    }

    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: NavigationView { view })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    private func withViewModel(
        screensaver: KioskScreensaverSettings,
        backgroundColor: String? = nil,
        iconColor: String? = nil,
        _ body: (KioskSettingsViewModel) throws -> Void
    ) throws {
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

        let settings = KioskSettings(
            serverId: Current.servers.all.first?.identifier.rawValue,
            settingsEntryBackgroundColor: backgroundColor,
            settingsEntryIconColor: iconColor,
            screensaver: screensaver
        )
        try database.write { db in
            try settings.insert(db, onConflict: .replace)
        }

        try body(KioskSettingsViewModel())
    }
}
