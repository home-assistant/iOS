import CoreLocation
import Foundation
import PromiseKit
@testable import Shared
import XCTest

class LocationPermissionSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func tearDown() {
        Current.location.permissionStatus = { CLLocationManager().authorizationStatus }

        super.tearDown()
    }

    func testSensorReportsInjectedStatus() throws {
        Current.location.permissionStatus = { .authorizedAlways }

        let sensors = try hang(LocationPermissionSensor(request: request).sensors())

        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, WebhookSensorId.locationPermission.rawValue)
        XCTAssertEqual(sensors[0].Name, "Location permission")
        XCTAssertEqual(sensors[0].State as? String, "Authorized Always")
        XCTAssertEqual(sensors[0].Icon, "mdi:map")

        Current.location.permissionStatus = { .denied }

        let updated = try hang(LocationPermissionSensor(request: request).sensors())
        XCTAssertEqual(updated[0].State as? String, "Denied")
    }

    func testStatusIsReadOffTheMainThread() throws {
        var readOnMainThread: Bool?
        Current.location.permissionStatus = {
            readOnMainThread = Thread.isMainThread
            return .notDetermined
        }

        let sensors = try hang(LocationPermissionSensor(request: request).sensors())

        XCTAssertEqual(sensors[0].State as? String, "Not determined")
        XCTAssertEqual(readOnMainThread, false)
    }
}
