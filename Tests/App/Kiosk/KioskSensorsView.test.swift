@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The kiosk sensors screen lists the kiosk sensors the container last reported, each with a
/// switch that turns it on or off for every server.
/// Shared state: swaps `Current.sensors`, `Current.servers`, `Current.backgroundTask` and
/// `Current.settingsStore` (a private defaults suite), and resets the sensor enablement store in it.
@Suite(.sharedState)
@MainActor
struct KioskSensorsViewTests {
    @Test func listsTheKioskSensorsWithTheirSwitches() async throws {
        // Sensor enablement (and both resets below) live in `Current.settingsStore.prefs`: point it at
        // defaults only this test owns, so the host app's sensor selections are never touched.
        let settings = PrivateSettingsStore()
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let previousRunner = Current.backgroundTask
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            Current.backgroundTask = previousRunner
            SensorEnablementStore.resetForTesting()
            settings.restore()
        }
        let servers = FakeServerManager(initial: 1)
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        let container = SensorContainer()
        container.register(provider: KioskModeSensor.self)
        Current.sensors = container
        // The screen refreshes the sensors when it appears; this runner fails that at once.
        Current.backgroundTask = NoTimeLeftBackgroundTaskRunner()

        container.setEnabledForAllServers(true, forUniqueID: WebhookSensorId.kioskMode.rawValue)
        let update = container.sensors(reason: .trigger("test"), server: servers.all[0])
        await withCheckedContinuation { continuation in
            update.done { _ in continuation.resume() }
        }

        let driver = await SwiftUIScreenDriver.show(KioskSensorsView())
        defer { driver.close() }
        await #expect(driver.waitUntil { driver.rowCount(inSection: 1) == 1 })

        await driver.toggleSwitches()
        #expect(!container.isEnabled(uniqueID: WebhookSensorId.kioskMode.rawValue, for: servers.all[0]))
    }
}

/// Fails every background task at once, without running the work it wraps.
private final class NoTimeLeftBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
