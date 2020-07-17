import Foundation
@testable import Shared
import PromiseKit
import XCTest
import DeviceKit

// swiftlint:disable large_tuple

class BatterySensorTests: XCTestCase {
    func testBattery0() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 0)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-outline")
        XCTAssertEqual(uState.Icon, "mdi:battery-outline")
        XCTAssertEqual(uLevel.State as? Int, 0)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-outline")
        XCTAssertEqual(cState.Icon, "mdi:battery-outline")
        XCTAssertEqual(cLevel.State as? Int, 0)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery10() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 10)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-10")
        XCTAssertEqual(uState.Icon, "mdi:battery-10")
        XCTAssertEqual(uLevel.State as? Int, 10)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-outline")
        XCTAssertEqual(cState.Icon, "mdi:battery-outline")
        XCTAssertEqual(cLevel.State as? Int, 10)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery19() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 19)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-10")
        XCTAssertEqual(uState.Icon, "mdi:battery-10")
        XCTAssertEqual(uLevel.State as? Int, 19)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-outline")
        XCTAssertEqual(cState.Icon, "mdi:battery-outline")
        XCTAssertEqual(cLevel.State as? Int, 19)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery20() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 20)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-20")
        XCTAssertEqual(uState.Icon, "mdi:battery-20")
        XCTAssertEqual(uLevel.State as? Int, 20)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-20")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-20")
        XCTAssertEqual(cLevel.State as? Int, 20)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery30() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 30)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-30")
        XCTAssertEqual(uState.Icon, "mdi:battery-30")
        XCTAssertEqual(uLevel.State as? Int, 30)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-20")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-20")
        XCTAssertEqual(cLevel.State as? Int, 30)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery40() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 40)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-40")
        XCTAssertEqual(uState.Icon, "mdi:battery-40")
        XCTAssertEqual(uLevel.State as? Int, 40)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-40")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-40")
        XCTAssertEqual(cLevel.State as? Int, 40)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery50() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 50)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-50")
        XCTAssertEqual(uState.Icon, "mdi:battery-50")
        XCTAssertEqual(uLevel.State as? Int, 50)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-40")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-40")
        XCTAssertEqual(cLevel.State as? Int, 50)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery60() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 60)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-60")
        XCTAssertEqual(uState.Icon, "mdi:battery-60")
        XCTAssertEqual(uLevel.State as? Int, 60)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-60")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-60")
        XCTAssertEqual(cLevel.State as? Int, 60)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery70() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 70)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-70")
        XCTAssertEqual(uState.Icon, "mdi:battery-70")
        XCTAssertEqual(uLevel.State as? Int, 70)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-60")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-60")
        XCTAssertEqual(cLevel.State as? Int, 70)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery80() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 80)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-80")
        XCTAssertEqual(uState.Icon, "mdi:battery-80")
        XCTAssertEqual(uLevel.State as? Int, 80)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cLevel.State as? Int, 80)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery90() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 90)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-90")
        XCTAssertEqual(uState.Icon, "mdi:battery-90")
        XCTAssertEqual(uLevel.State as? Int, 90)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cLevel.State as? Int, 90)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery99() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 99)
        XCTAssertEqual(uLevel.Icon, "mdi:battery-90")
        XCTAssertEqual(uState.Icon, "mdi:battery-90")
        XCTAssertEqual(uLevel.State as? Int, 99)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-80")
        XCTAssertEqual(cLevel.State as? Int, 99)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBattery100ButNotFull() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 100, forceNotFull: true)
        XCTAssertEqual(uLevel.Icon, "mdi:battery")
        XCTAssertEqual(uState.Icon, "mdi:battery")
        XCTAssertEqual(uLevel.State as? Int, 100)
        XCTAssertEqual(uState.State as? String, "Not Charging")

        XCTAssertEqual(cLevel.Icon, "mdi:battery-charging-100")
        XCTAssertEqual(cState.Icon, "mdi:battery-charging-100")
        XCTAssertEqual(cLevel.State as? Int, 100)
        XCTAssertEqual(cState.State as? String, "Charging")
    }

    func testBatteryFull() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 100)
        XCTAssertEqual(uLevel.Icon, "mdi:battery")
        XCTAssertEqual(uState.Icon, "mdi:battery")
        XCTAssertEqual(uLevel.State as? Int, 100)
        XCTAssertEqual(uState.State as? String, "Full")

        XCTAssertEqual(cLevel.Icon, "mdi:battery")
        XCTAssertEqual(cState.Icon, "mdi:battery")
        XCTAssertEqual(cLevel.State as? Int, 100)
        XCTAssertEqual(cState.State as? String, "Full")
    }

    func testSimulatorLevelOverride() throws {
        Current.device.batteryLevel = { -100 }
        Current.device.batteryState = { .full }

        let promise = BatterySensor(request: .init(reason: .trigger("unit-test"))).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 2)

        let level = sensors[0]
        XCTAssertEqual(level.State as? Int, 100)
    }

    private func XCTAssertLevel(_ sensor: WebhookSensor, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(sensor.Name, "Battery Level", file: file, line: line)
        XCTAssertEqual(sensor.UniqueID, "battery_level", file: file, line: line)
        XCTAssertEqual(sensor.DeviceClass, .battery, file: file, line: line)
        XCTAssertEqual(sensor.UnitOfMeasurement, "%", file: file, line: line)
    }

    private func XCTAssertState(_ sensor: WebhookSensor, file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(sensor.Name, "Battery State", file: file, line: line)
        XCTAssertEqual(sensor.UniqueID, "battery_state", file: file, line: line)
        XCTAssertEqual(sensor.DeviceClass, .battery, file: file, line: line)
    }

    func sensors(
        level: Int,
        forceNotFull: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> (uLevel: WebhookSensor, uState: WebhookSensor, cLevel: WebhookSensor, cState: WebhookSensor) {
        Current.device.batteryLevel = { level }
        Current.device.batteryState = { level == 100 && !forceNotFull ? .full : .unplugged(level) }
        Current.device.isLowPowerMode = { true }

        let uPromise = BatterySensor(request: .init(reason: .trigger("unit-test"))).sensors()
        let uSensors = try hang(uPromise)
        XCTAssertEqual(uSensors.count, 2)

        let uLevel = uSensors[0]
        let uState = uSensors[1]

        XCTAssertLevel(uLevel, file: file, line: line)
        XCTAssertEqual(uLevel.Attributes?["Battery State"] as? String, uState.State as? String, file: file, line: line)
        XCTAssertEqual(uLevel.Attributes?["Low Power Mode"] as? Bool, true)

        XCTAssertState(uState, file: file, line: line)
        XCTAssertEqual(uState.Attributes?["Battery Level"] as? Int, uLevel.State as? Int, file: file, line: line)
        XCTAssertEqual(uState.Attributes?["Low Power Mode"] as? Bool, true)

        Current.device.batteryLevel = { level }
        Current.device.batteryState = { level == 100 && !forceNotFull ? .full : .charging(level) }
        Current.device.isLowPowerMode = { true }

        let cPromise = BatterySensor(request: .init(reason: .trigger("unit-test"))).sensors()
        let cSensors = try hang(cPromise)
        XCTAssertEqual(cSensors.count, 2)

        let cLevel = cSensors[0]
        let cState = cSensors[1]

        XCTAssertLevel(cLevel, file: file, line: line)
        XCTAssertEqual(cLevel.Attributes?["Battery State"] as? String, cState.State as? String, file: file, line: line)
        XCTAssertEqual(cLevel.Attributes?["Low Power Mode"] as? Bool, true)

        XCTAssertState(cState, file: file, line: line)
        XCTAssertEqual(cState.Attributes?["Battery Level"] as? Int, cLevel.State as? Int, file: file, line: line)
        XCTAssertEqual(cState.Attributes?["Low Power Mode"] as? Bool, true)

        return (uLevel, uState, cLevel, cState)
    }

}
