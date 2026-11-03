import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Hosts the kiosk wrapper around the app container: the settings entry in each corner, and the
/// screensaver once kiosk mode asks for it. Also checks that touches anywhere in the window count as
/// activity.
/// Shared state: swaps `Current.database`, `Current.kiosk`, `Current.servers` and `Current.sensors`,
/// and the container registers its coordinator with the scene manager (restored afterwards).
@Suite(.sharedState)
@MainActor
struct KioskViewTests {
    /// Runs `body` with kiosk mode on, read from a database of its own, and puts everything back.
    private func withKioskMode(_ body: (KioskModeManager, DatabaseQueue) async throws -> Void) async throws {
        let database = try SettingsTestDatabase.make()
        try await database.write { db in
            var settings = KioskSettings()
            settings.enabled = true
            settings.screensaver.enabled = true
            try settings.insert(db, onConflict: .replace)
        }
        let previousDatabase = Current.database
        let previousKiosk = Current.kiosk
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let previousCoordinator = Current.sceneManager.appCoordinator.value
        Current.database = { database }
        Current.servers = FakeServerManager(initial: 0)
        Current.sensors = SensorContainer()
        let kiosk = KioskModeManager()
        Current.kiosk = kiosk
        defer {
            Current.kiosk = previousKiosk
            Current.database = previousDatabase
            Current.servers = previousServers
            Current.sensors = previousSensors
            if let previousCoordinator {
                Current.sceneManager.registerAppCoordinator(previousCoordinator)
            }
        }

        try await body(kiosk, database)
    }

    @Test func wrapsTheContainerWithTheEntryAndTheScreensaver() async throws {
        try await withKioskMode { kiosk, database in
            let driver = await SwiftUIScreenDriver.show(
                KioskView(appSettings: AppSettingsPresenter(), showSettings: .constant(false)),
                inNavigationStack: false
            )
            defer { driver.close() }

            for position in KioskCornerPosition.allCases {
                try await database.write { db in
                    var settings = try KioskSettings.fetchOne(db) ?? KioskSettings()
                    settings.settingsEntryPosition = position
                    try settings.update(db)
                }
                await #expect(driver.waitUntil { kiosk.settings.settingsEntryPosition == position })
                await driver.settle()
            }

            kiosk.requestScreensaver(.show)
            await #expect(driver.waitUntil { kiosk.isScreensaverVisible })
            kiosk.requestScreensaver(.hide)
            await #expect(driver.waitUntil { !kiosk.isScreensaverVisible })
        }
    }

    /// With kiosk mode on, the app's root container wraps itself in the kiosk view.
    @Test func theRootContainerSwitchesToKioskMode() async throws {
        let idleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        defer { UIApplication.shared.isIdleTimerDisabled = idleTimerDisabled }
        try await withKioskMode { kiosk, _ in
            let driver = await SwiftUIScreenDriver.show(
                ConditionalContainerView(appSettings: AppSettingsPresenter()),
                inNavigationStack: false
            )
            defer { driver.close() }
            #expect(kiosk.settings.enabled)
        }
    }

    /// The detector puts a recognizer on its window that reports every touch, without competing
    /// with the window's other recognizers, and takes it away again when it leaves the window.
    @Test func touchesAnywhereInTheWindowCountAsActivity() async throws {
        var activity = 0
        let driver = await SwiftUIScreenDriver.show(
            KioskActivityDetector { activity += 1 }.frame(width: 100, height: 100),
            size: CGSize(width: 200, height: 200),
            inNavigationStack: false
        )
        let window = driver.window
        let recognizers = (window.gestureRecognizers ?? []).filter { $0.delegate != nil && $0.view === window }
        let recognizer = try #require(recognizers.last)

        recognizer.touchesBegan([], with: UIEvent())
        recognizer.touchesMoved([], with: UIEvent())
        #expect(activity == 2)
        #expect(
            recognizer.delegate?
                .gestureRecognizer?(recognizer, shouldRecognizeSimultaneouslyWith: recognizer) == true
        )

        driver.close()
        await driver.settle()
        #expect(!(window.gestureRecognizers ?? []).contains(recognizer))
    }
}
