@testable import Shared
import XCTest
import PromiseKit

class DeviceSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil
    )

    private func sensors(for screens: [DeviceScreen]) throws -> (displays: WebhookSensor, primary: WebhookSensor) {
        Current.device.screens = { screens }
        let promise = DisplaySensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 2)
        return (displays: sensors[0], primary: sensors[1])
    }

    func testNotAvailable() {
        Current.device.screens = { nil }

        let promise = DisplaySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? DisplaySensor.DisplayError, .unsupportedPlatform)
        }
    }

    func testSignaler() {
        var didSignal = false
        let signaler = DisplaySensorUpdateSignaler(signal: {
            didSignal = true
        })

        withExtendedLifetime(signaler) {
            NotificationCenter.default.post(name: DisplaySensorUpdateSignaler.notificationName, object: nil)
            XCTAssertTrue(didSignal)
        }
    }

    func testUpdateSignalerCreated() throws {
        Current.device.batteries = { [ DeviceBattery(level: 100, state: .unplugged, attributes: [:]) ] }

        let dependencies = SensorProviderDependencies()
        let provider = DisplaySensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil
        ))
        let promise = provider.sensors()
        _ = try hang(promise)

        let signaler: DisplaySensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testNoDisplay() throws {
        let (displays, primary) = try sensors(for: [])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 0)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], [])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], [])

        XCTAssertEqual(primary.UniqueID, "primary_display")
        XCTAssertEqual(primary.Icon, "mdi:monitor-star")
        XCTAssertEqual(primary.Name, "Primary Display")
        XCTAssertEqual(primary.State as? String, "None")
        XCTAssertEqual(primary.Attributes?["Display ID"] as? String, "None")
    }

    func testOneDisplay() throws {
        let (displays, primary) = try sensors(for: [.init(identifier: "identifier", name: "name")])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 1)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], ["identifier"])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], ["name"])

        XCTAssertEqual(primary.UniqueID, "primary_display")
        XCTAssertEqual(primary.Icon, "mdi:monitor-star")
        XCTAssertEqual(primary.Name, "Primary Display")
        XCTAssertEqual(primary.State as? String, "name")
        XCTAssertEqual(primary.Attributes?["Display ID"] as? String, "identifier")
    }

    func testTwoDisplay() throws {
        let (displays, primary) = try sensors(for: [
            .init(identifier: "identifier1", name: "name1"),
            .init(identifier: "identifier2", name: "name2")
        ])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 2)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], ["identifier1", "identifier2"])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], ["name1", "name2"])

        XCTAssertEqual(primary.UniqueID, "primary_display")
        XCTAssertEqual(primary.Icon, "mdi:monitor-star")
        XCTAssertEqual(primary.Name, "Primary Display")
        XCTAssertEqual(primary.State as? String, "name1")
        XCTAssertEqual(primary.Attributes?["Display ID"] as? String, "identifier1")
    }
}
