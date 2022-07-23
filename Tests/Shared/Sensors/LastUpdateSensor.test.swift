import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class LastUpdateSensorTests: XCTestCase {
    func testManualTriggerOnPhone() throws {
        Current.isCatalyst = false

        let request: SensorProviderRequest = .init(
            reason: .trigger("Manual"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )
        let promise = LastUpdateSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "last_update_trigger")
        XCTAssertEqual(sensors[0].Name, "Last Update Trigger")
        XCTAssertEqual(sensors[0].Icon, "mdi:cellphone-wireless")
        XCTAssertEqual(sensors[0].State as? String, "Manual")
    }

    func testManualTriggerOnMacBook() throws {
        Current.isCatalyst = true
        Current.device.systemModel = { "MacBookPro1,1" }

        let request: SensorProviderRequest = .init(
            reason: .trigger("Manual"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )
        let promise = LastUpdateSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "last_update_trigger")
        XCTAssertEqual(sensors[0].Name, "Last Update Trigger")
        XCTAssertEqual(sensors[0].Icon, "mdi:laptop")
        XCTAssertEqual(sensors[0].State as? String, "Manual")
    }

    func testManualTriggerOnMacMini() throws {
        Current.isCatalyst = true
        Current.device.systemModel = { "Macmini1,1" }

        let request: SensorProviderRequest = .init(
            reason: .trigger("Manual"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )
        let promise = LastUpdateSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "last_update_trigger")
        XCTAssertEqual(sensors[0].Name, "Last Update Trigger")
        XCTAssertEqual(sensors[0].Icon, "mdi:monitor")
        XCTAssertEqual(sensors[0].State as? String, "Manual")
    }

    func testManualTriggerOniMac() throws {
        Current.isCatalyst = true
        Current.device.systemModel = { "iMac1,1" }

        let request: SensorProviderRequest = .init(
            reason: .trigger("Manual"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )
        let promise = LastUpdateSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "last_update_trigger")
        XCTAssertEqual(sensors[0].Name, "Last Update Trigger")
        XCTAssertEqual(sensors[0].Icon, "mdi:monitor")
        XCTAssertEqual(sensors[0].State as? String, "Manual")
    }
}
