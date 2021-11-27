import PromiseKit
@testable import Shared
import Version
import XCTest

class DeviceSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    private func sensors(for screens: [DeviceScreen]) throws -> (
        displays: WebhookSensor,
        primaryName: WebhookSensor,
        primaryID: WebhookSensor
    ) {
        Current.device.screens = { screens }
        let promise = DisplaySensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 3)
        return (displays: sensors[0], primaryName: sensors[1], primaryID: sensors[2])
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
        Current.device.batteries = { [DeviceBattery(level: 100, state: .unplugged, attributes: [:])] }

        let dependencies = SensorProviderDependencies()
        let provider = DisplaySensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let promise = provider.sensors()
        _ = try hang(promise)

        let signaler: DisplaySensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testNoDisplay() throws {
        let (displays, primaryName, primaryID) = try sensors(for: [])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 0)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], [])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], [])

        XCTAssertEqual(primaryName.UniqueID, "primary_display_name")
        XCTAssertEqual(primaryName.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryName.Name, "Primary Display Name")
        XCTAssertEqual(primaryName.State as? String, "None")

        XCTAssertEqual(primaryID.UniqueID, "primary_display_id")
        XCTAssertEqual(primaryID.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryID.Name, "Primary Display ID")
        XCTAssertEqual(primaryID.State as? String, "None")
    }

    func testOneDisplay() throws {
        let (displays, primaryName, primaryID) = try sensors(for: [.init(identifier: "identifier", name: "name")])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 1)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], ["identifier"])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], ["name"])

        XCTAssertEqual(primaryName.UniqueID, "primary_display_name")
        XCTAssertEqual(primaryName.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryName.Name, "Primary Display Name")
        XCTAssertEqual(primaryName.State as? String, "name")

        XCTAssertEqual(primaryID.UniqueID, "primary_display_id")
        XCTAssertEqual(primaryID.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryID.Name, "Primary Display ID")
        XCTAssertEqual(primaryID.State as? String, "identifier")
    }

    func testTwoDisplay() throws {
        let (displays, primaryName, primaryID) = try sensors(for: [
            .init(identifier: "identifier1", name: "name1"),
            .init(identifier: "identifier2", name: "name2"),
        ])

        XCTAssertEqual(displays.UniqueID, "displays_count")
        XCTAssertEqual(displays.Icon, "mdi:monitor-multiple")
        XCTAssertEqual(displays.Name, "Displays")
        XCTAssertEqual(displays.State as? Int, 2)
        XCTAssertEqual(displays.Attributes?["Display IDs"] as? [String], ["identifier1", "identifier2"])
        XCTAssertEqual(displays.Attributes?["Display Names"] as? [String], ["name1", "name2"])

        XCTAssertEqual(primaryName.UniqueID, "primary_display_name")
        XCTAssertEqual(primaryName.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryName.Name, "Primary Display Name")
        XCTAssertEqual(primaryName.State as? String, "name1")

        XCTAssertEqual(primaryID.UniqueID, "primary_display_id")
        XCTAssertEqual(primaryID.Icon, "mdi:monitor-star")
        XCTAssertEqual(primaryID.Name, "Primary Display ID")
        XCTAssertEqual(primaryID.State as? String, "identifier1")
    }
}
