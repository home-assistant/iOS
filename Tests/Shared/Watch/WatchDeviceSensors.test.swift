import Foundation
@testable import Shared
import Testing

// Serialized: the tests override the shared `Current.device`, which concurrent tests would race on.
@Suite(.serialized)
struct WatchDeviceSensorsTests {
    /// Runs `body` with the device reporting one battery at `level`, charging, restoring the shared
    /// environment afterwards so other suites see the defaults.
    private func withChargingBattery<T>(level: Int = 80, _ body: () throws -> T) rethrows -> T {
        let batteries = Current.device.batteries
        let isLowPowerMode = Current.device.isLowPowerMode
        defer {
            Current.device.batteries = batteries
            Current.device.isLowPowerMode = isLowPowerMode
        }
        Current.device.batteries = { [DeviceBattery(level: level, state: .charging, attributes: [:])] }
        Current.device.isLowPowerMode = { false }
        return try body()
    }

    @Test func listsBatteryLevelAndState() {
        #expect(WatchDeviceSensors.all.map(\.uniqueID) == ["battery_level", "battery_state"])
        #expect(WatchDeviceSensors.all.map(\.name) == ["Battery Level", "Battery State"])
    }

    @Test func currentReadsTheWatchBatteryLikeThePhoneDoes() {
        let sensors = withChargingBattery { WatchDeviceSensors.current() }

        #expect(sensors.map(\.UniqueID) == ["battery_level", "battery_state"])
        #expect(sensors[0].Name == "Battery Level")
        #expect(sensors[0].State as? Int == 80)
        #expect(sensors[0].UnitOfMeasurement == "%")
        #expect(sensors[0].DeviceClass == .battery)
        #expect(sensors[0].Icon == "mdi:battery-charging-80")
        #expect(sensors[1].Name == "Battery State")
        #expect(sensors[1].State as? String == "Charging")
    }

    @Test func unreadableBatteryIsReportedUnavailable() {
        let sensors = withChargingBattery(level: -1) { WatchDeviceSensors.current() }

        #expect(sensors.map(\.UniqueID) == ["battery_level", "battery_state"])
        #expect(sensors[0].State as? String == "unavailable")
        #expect(sensors[1].State as? String == "unavailable")
    }

    @Test func registrationPayloadCarriesEnablement() throws {
        let sensor = try #require(withChargingBattery { WatchDeviceSensors.current().first })

        let enabled = WatchDeviceSensors.registrationPayload(sensor: sensor, enabled: true)
        #expect(enabled["unique_id"] as? String == "battery_level")
        #expect(enabled["name"] as? String == "Battery Level")
        #expect(enabled["disabled"] as? Bool == false)
        #expect(enabled["state"] as? Int == 80)
    }

    @Test func registrationPayloadRedactsASensorThatIsOff() throws {
        let sensor = try #require(withChargingBattery { WatchDeviceSensors.current().first })

        let disabled = WatchDeviceSensors.registrationPayload(sensor: sensor, enabled: false)
        #expect(disabled["unique_id"] as? String == "battery_level")
        #expect(disabled["name"] as? String == "Battery Level")
        #expect(disabled["disabled"] as? Bool == true)
        #expect(disabled["state"] as? String == "unavailable")
    }

    @Test func updatePayloadRedactsSensorsThatAreOff() throws {
        let payload = WatchDeviceSensors.updatePayload(
            sensors: withChargingBattery { WatchDeviceSensors.current() },
            enabledIDs: ["battery_level"]
        )

        #expect(payload.count == 2)
        let level = try #require(payload.first { $0["unique_id"] as? String == "battery_level" })
        #expect(level["state"] as? Int == 80)
        // Registration-only fields stay out of a state update.
        #expect(level["name"] == nil)
        #expect(level["disabled"] == nil)

        let state = try #require(payload.first { $0["unique_id"] as? String == "battery_state" })
        #expect(state["state"] as? String == "unavailable")
    }

    @Test func findsSensorsTheServerDoesNotKnow() {
        let response: [String: [String: Any]] = [
            "battery_level": ["success": true],
            "battery_state": [
                "success": false,
                "error": ["code": "not_registered", "message": "Entity is not registered"],
            ],
        ]

        #expect(WatchDeviceSensors.unregisteredIDs(in: response) == ["battery_state"])
        #expect(WatchDeviceSensors.rejections(in: response).isEmpty)
        #expect(WatchDeviceSensors.unregisteredIDs(in: ()) == [])
        #expect(WatchDeviceSensors.unregisteredIDs(in: ["battery_level": ["success": true]]) == [])
    }

    @Test func findsSensorsTheServerRejected() {
        let response: [String: [String: Any]] = [
            "battery_level": ["success": true],
            "battery_state": [
                "success": false,
                "error": ["code": "invalid_format", "message": "Unexpected value for state"],
            ],
        ]

        #expect(WatchDeviceSensors.rejections(in: response) == ["battery_state": "Unexpected value for state"])
        #expect(WatchDeviceSensors.unregisteredIDs(in: response) == [])
    }
}
