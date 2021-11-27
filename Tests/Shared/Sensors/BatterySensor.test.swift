import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class BatterySensorTests: XCTestCase {
    func testUpdateSignalerCreated() throws {
        Current.device.batteries = { [DeviceBattery(level: 100, state: .unplugged, attributes: [:])] }

        let dependencies = SensorProviderDependencies()
        let provider = BatterySensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let promise = provider.sensors()
        _ = try hang(promise)

        let signaler: BatterySensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testSignaler() {
        var didSignal = false
        let signaler = BatterySensorUpdateSignaler(signal: {
            didSignal = true
        })

        signaler.deviceBatteryStateDidChange(Current.device.batteryNotificationCenter)
        XCTAssertTrue(didSignal)
    }

    func testAdditionalInfo() throws {
        let (uLevel, uState, cLevel, cState) = try sensors(level: 100, attributes: ["test": true])
        XCTAssertEqual(uLevel.Attributes?["test"] as? Bool, true)
        XCTAssertEqual(uState.Attributes?["test"] as? Bool, true)
        XCTAssertEqual(cLevel.Attributes?["test"] as? Bool, true)
        XCTAssertEqual(cState.Attributes?["test"] as? Bool, true)
    }

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

    func testMultipleBatteries() throws {
        let (unplugged, charging) = try sensors(levels: [0, 99], names: ["one", "two"], uniqueIds: ["u1", "u2"])

        XCTAssertEqual(unplugged[0].level.State as? Int, 0)
        XCTAssertEqual(unplugged[0].state.State as? String, "Not Charging")
        XCTAssertEqual(unplugged[1].level.State as? Int, 99)
        XCTAssertEqual(unplugged[1].state.State as? String, "Not Charging")

        XCTAssertEqual(charging[0].level.State as? Int, 0)
        XCTAssertEqual(charging[0].state.State as? String, "Charging")
        XCTAssertEqual(charging[1].level.State as? Int, 99)
        XCTAssertEqual(charging[1].state.State as? String, "Charging")
    }

    func testNoBatteries() throws {
        let (unplugged, charging) = try sensors(levels: [])
        XCTAssertTrue(unplugged.isEmpty)
        XCTAssertTrue(charging.isEmpty)
    }

    private func XCTAssertLevel(
        _ sensor: WebhookSensor,
        name: String? = nil,
        uniqueId: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(sensor.Name, "\(name ?? "Battery") Level", file: file, line: line)
        XCTAssertEqual(sensor.UniqueID, "\(uniqueId ?? "battery")_level", file: file, line: line)
        XCTAssertEqual(sensor.DeviceClass, .battery, file: file, line: line)
        XCTAssertEqual(sensor.UnitOfMeasurement, "%", file: file, line: line)
    }

    private func XCTAssertState(
        _ sensor: WebhookSensor,
        name: String? = nil,
        uniqueId: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(sensor.Name, "\(name ?? "Battery") State", file: file, line: line)
        XCTAssertEqual(sensor.UniqueID, "\(uniqueId ?? "battery")_state", file: file, line: line)
    }

    func sensors(
        level: Int,
        forceNotFull: Bool = false,
        attributes: [String: Any] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (uLevel: WebhookSensor, uState: WebhookSensor, cLevel: WebhookSensor, cState: WebhookSensor) {
        let (u, c) = try sensors(
            levels: [level],
            forceNotFull: forceNotFull,
            attributes: attributes,
            file: file,
            line: line
        )
        return (uLevel: u[0].level, uState: u[0].state, cLevel: c[0].level, cState: c[0].state)
    }

    func sensors(
        levels: [Int],
        names: [String] = [],
        uniqueIds: [String] = [],
        forceNotFull: Bool = false,
        attributes: [String: Any] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (u: [(level: WebhookSensor, state: WebhookSensor)], c: [(level: WebhookSensor, state: WebhookSensor)]) {
        Current.device.batteries = {
            levels.enumerated().map { idx, level in
                var battery = DeviceBattery(
                    level: level,
                    state: level == 100 && !forceNotFull ? .full : .unplugged,
                    attributes: attributes
                )

                if !names.isEmpty {
                    battery.name = names[idx]
                }

                if !uniqueIds.isEmpty {
                    battery.uniqueID = uniqueIds[idx]
                }

                return battery
            }
        }

        Current.device.isLowPowerMode = { true }

        let uPromise = BatterySensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )).sensors()
        let uSensors = try hang(uPromise)
        XCTAssertEqual(uSensors.count, levels.count * 2)

        var uReturn = [(level: WebhookSensor, state: WebhookSensor)]()

        for idx in stride(from: 0, to: uSensors.count, by: 2) {
            let uLevel = uSensors[idx]
            let uState = uSensors[idx + 1]

            XCTAssertLevel(
                uLevel,
                name: names.isEmpty ? nil : names[idx / 2],
                uniqueId: uniqueIds.isEmpty ? nil : uniqueIds[idx / 2],
                file: file,
                line: line
            )

            XCTAssertState(
                uState,
                name: names.isEmpty ? nil : names[idx / 2],
                uniqueId: uniqueIds.isEmpty ? nil : uniqueIds[idx / 2],
                file: file,
                line: line
            )
            XCTAssertEqual(uState.Attributes?["Low Power Mode"] as? Bool, true)

            uReturn.append((level: uLevel, state: uState))
        }

        Current.device.batteries = {
            levels.enumerated().map { idx, level in
                var battery = DeviceBattery(
                    level: level,
                    state: level == 100 && !forceNotFull ? .full : .charging,
                    attributes: attributes
                )

                if !names.isEmpty {
                    battery.name = names[idx]
                }

                if !uniqueIds.isEmpty {
                    battery.uniqueID = uniqueIds[idx]
                }

                return battery
            }
        }

        Current.device.isLowPowerMode = { true }

        let cPromise = BatterySensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )).sensors()
        let cSensors = try hang(cPromise)
        XCTAssertEqual(cSensors.count, levels.count * 2)

        var cReturn = [(level: WebhookSensor, state: WebhookSensor)]()

        for idx in stride(from: 0, to: cSensors.count, by: 2) {
            let cLevel = cSensors[idx]
            let cState = cSensors[idx + 1]

            XCTAssertLevel(
                cLevel,
                name: names.isEmpty ? nil : names[idx / 2],
                uniqueId: uniqueIds.isEmpty ? nil : uniqueIds[idx / 2],
                file: file,
                line: line
            )

            XCTAssertState(
                cState,
                name: names.isEmpty ? nil : names[idx / 2],
                uniqueId: uniqueIds.isEmpty ? nil : uniqueIds[idx / 2],
                file: file,
                line: line
            )
            XCTAssertEqual(cState.Attributes?["Low Power Mode"] as? Bool, true)

            cReturn.append((level: cLevel, state: cState))
        }

        return (uReturn, cReturn)
    }
}
