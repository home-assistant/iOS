import Foundation
import PromiseKit
@testable import Shared
import XCTest

class StorageSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    func testNilDataReturnsError() {
        Current.device.volumes = { nil }
        let promise = StorageSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? StorageSensor.StorageError, .noData)
        }
    }

    func testEmptyDataReturnsError() {
        Current.device.volumes = { [:] }
        let promise = StorageSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? StorageSensor.StorageError, .noData)
        }
    }

    func testMissingKeyReturnsError() {
        Current.device.volumes = { [
            .volumeTotalCapacityKey: 0,
            .volumeAvailableCapacityForImportantUsageKey: 100,
            .volumeAvailableCapacityForOpportunisticUsageKey: 100,
        ] }
        let promise = StorageSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? StorageSensor.StorageError, .missingData(.volumeAvailableCapacityKey))
        }
    }

    func testZeroDenominator() {
        Current.device.volumes = { [
            .volumeTotalCapacityKey: 0,
            .volumeAvailableCapacityKey: 100,
            .volumeAvailableCapacityForImportantUsageKey: 100,
            .volumeAvailableCapacityForOpportunisticUsageKey: 100,
        ] }
        let promise = StorageSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? StorageSensor.StorageError, .invalidData)
        }
    }

    func testBasicSensor() throws {
        Current.device.volumes = { [
            .volumeTotalCapacityKey: 100_000_000_000,
            .volumeAvailableCapacityKey: 20_000_000_000,
            .volumeAvailableCapacityForImportantUsageKey: 21_000_000_000,
            .volumeAvailableCapacityForOpportunisticUsageKey: 22_000_000_000,
        ] }
        let promise = StorageSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Name, "Storage")
        XCTAssertEqual(sensors[0].UniqueID, "storage")
        XCTAssertEqual(sensors[0].Icon, "mdi:database")
        XCTAssertEqual(sensors[0].State as? String, "21.00")
        XCTAssertEqual(sensors[0].UnitOfMeasurement, "% available")
        XCTAssertEqual(sensors[0].Attributes?["Total"] as? String, "100.00 GB")
        XCTAssertEqual(sensors[0].Attributes?["Available"] as? String, "20.00 GB")
        XCTAssertEqual(sensors[0].Attributes?["Available (Important)"] as? String, "21.00 GB")
        XCTAssertEqual(sensors[0].Attributes?["Available (Opportunistic)"] as? String, "22.00 GB")
    }

    func testZeroOpportunisticStillReportsImportantCapacity() throws {
        // iOS reports 0 opportunistic capacity once it nears its reserve threshold, even though
        // Settings still shows tens of GB free. The state must follow the "important" value.
        Current.device.volumes = { [
            .volumeTotalCapacityKey: 254_910_000_000,
            .volumeAvailableCapacityKey: 3_170_000_000,
            .volumeAvailableCapacityForImportantUsageKey: 35_670_000_000,
            .volumeAvailableCapacityForOpportunisticUsageKey: 0,
        ] }
        let sensors = try hang(StorageSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "13.99")
        XCTAssertEqual(sensors[0].Attributes?["Available (Opportunistic)"] as? String, "0.00 GB")
    }
}
