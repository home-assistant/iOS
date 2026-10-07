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

    private var previousPermissionStatus: (() -> CLAuthorizationStatus)!

    override func setUp() {
        super.setUp()

        previousPermissionStatus = Current.location.permissionStatus
    }

    override func tearDown() {
        Current.location.permissionStatus = previousPermissionStatus

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
        let lock = NSLock()
        var readOnMainThread: Bool?
        Current.location.permissionStatus = {
            lock.lock()
            readOnMainThread = Thread.isMainThread
            lock.unlock()
            return .notDetermined
        }

        let sensors = try hang(LocationPermissionSensor(request: request).sensors())

        XCTAssertEqual(sensors[0].State as? String, "Not determined")

        lock.lock()
        let wasReadOnMainThread = readOnMainThread
        lock.unlock()
        XCTAssertEqual(wasReadOnMainThread, false)
    }
}
