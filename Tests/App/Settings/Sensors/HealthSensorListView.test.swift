@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Lays the Apple Health sensor list out, switches metrics on and off, and searches.
///
/// `.sharedState`: the test swaps `Current.healthKitService`, `Current.servers` and `Current.sensors`,
/// and switching a metric on writes the sensor settings.
///
/// `Current.sensors` is a container of the test's own: switching metrics on signals every observer of
/// the process-wide container, and in a full run that wakes the app's sensor machinery (and whatever
/// earlier tests left registered) into a stream of sensor updates on the main thread.
@Suite(.sharedState)
@MainActor
struct HealthSensorListViewTests {
    private struct AccessDenied: Error {}

    private func withHealth(_ body: (Server) async throws -> Void) async rethrows {
        let previousService = Current.healthKitService
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        let manager = FakeServerManager(initial: 1)
        let server = manager.all[0]
        Current.servers = manager
        Current.sensors = SensorContainer()
        Current.healthKitService.isAvailable = { true }
        Current.healthKitService.requestReadAuthorization = { throw AccessDenied() }
        defer {
            Current.sensors.setEnabled(false, forUniqueIDs: HealthKitMetric.all.map(\.uniqueID), on: server)
            Current.sensors = previousSensors
            Current.healthKitService = previousService
            Current.servers = previousServers
        }
        try await body(server)
    }

    /// The "enable all" switch only asks for confirmation, through an alert this test does not wait for
    /// (the view model's own tests cover what confirming does); the other switches turn single metrics
    /// on. Switching off whatever is on then turns every metric off again: through "enable all" when
    /// the first pass reached every metric, one row at a time otherwise.
    ///
    /// The window is tall enough for every row, and only switches that are on are flipped back: the
    /// list lays rows out lazily, so a second flip-everything pass can meet rows the first one never
    /// saw and switch those on.
    @Test func switchesMetricsOnAndOff() async {
        await withHealth { server in
            let harness = await SettingsScreenHarness.show(
                HealthSensorListView(server: server),
                size: CGSize(width: 390, height: 6000)
            )
            let reached1 = await harness.waitUntil { harness.rows.count > 3 }
            #expect(reached1)

            await harness.toggleSwitches()
            let enabledAfterSwitchingOn = Current.sensors.enabledUniqueIDs(for: server).count
            #expect(enabledAfterSwitchingOn > 0)

            // Turning the visible switches back off narrows the selection; it is not asserted to empty
            // it, since not every identifier switched on above has a switch of its own in the list.
            let reached2 = await harness.waitUntil {
                for toggle in harness.views(of: UISwitch.self, in: harness.topView) where toggle.isOn {
                    toggle.setOn(false, animated: false)
                    toggle.sendActions(for: .valueChanged)
                }
                return Current.sensors.enabledUniqueIDs(for: server).count < enabledAfterSwitchingOn
            }
            #expect(reached2)
            await harness.close()
        }
    }

    @Test func searchingNarrowsTheMetrics() async {
        await withHealth { server in
            let harness = await SettingsScreenHarness.show(HealthSensorListView(server: server))
            let reached3 = await harness.waitUntil { harness.rows.count > 3 }
            #expect(reached3)
            let all = harness.rows.count

            await harness.search("step")
            #expect(harness.rows.count < all)
            await harness.search("no metric is called this")
            #expect(harness.rows.count == 1)
            await harness.close()
        }
    }
}

/// Fails every background task at once, without running the work it wraps.
private final class OutOfTimeTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
