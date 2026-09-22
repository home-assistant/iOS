@testable import HomeAssistant
@testable import Shared
import Testing

/// Kiosk mode belongs to the device rather than to one server, so its sensors screen switches them
/// on everywhere at once — the per-server choice lives in Settings > Sensors.
@Suite(.serialized)
@MainActor
struct KioskSensorsViewModelTests {
    @Test func switchingAKioskSensorOnCoversEveryServer() throws {
        try withServers { servers in
            let viewModel = KioskSensorsViewModel()
            let sensor = WebhookSensor(name: "Brightness", uniqueID: WebhookSensorId.kioskBrightness.rawValue)

            #expect(!viewModel.isEnabled(sensor))

            viewModel.setEnabled(true, for: sensor)

            #expect(viewModel.isEnabled(sensor))
            for server in servers.all {
                #expect(Current.sensors.isEnabled(sensor: sensor, for: server))
            }

            viewModel.setEnabled(false, for: sensor)

            for server in servers.all {
                #expect(!Current.sensors.isEnabled(sensor: sensor, for: server))
            }
        }
    }

    /// Nothing can be stored against a sensor with no unique ID, so the row is left alone rather
    /// than writing an empty key.
    @Test func aSensorWithoutAUniqueIDIsIgnored() throws {
        try withServers { servers in
            let viewModel = KioskSensorsViewModel()

            viewModel.setEnabled(true, for: WebhookSensor())

            #expect(servers.all.allSatisfy { Current.sensors.enabledUniqueIDs(for: $0).isEmpty })
        }
    }

    private func withServers(_ body: (FakeServerManager) throws -> Void) throws {
        let previousServers = Current.servers
        let previousSensors = Current.sensors
        defer {
            Current.servers = previousServers
            Current.sensors = previousSensors
            SensorEnablementStore.resetForTesting()
        }

        let servers = FakeServerManager(initial: 2)
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors = SensorContainer()
        Current.sensors.resetSensorsForFirstRun()
        try body(servers)
    }
}
