import CoreMotion
import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class PedometerSensorTests: XCTestCase {
    private enum TestError: Error {
        case someError
    }

    private var request: SensorProviderRequest!

    override func setUp() {
        super.setUp()

        request = .init(
            reason: .trigger("unit-test"),
            dependencies: .init(),
            location: nil,
            serverVersion: Version()
        )

        // start by assuming nothing is enabled/available
        Current.pedometer.isAuthorized = { false }
        Current.pedometer.isStepCountingAvailable = { false }
        Current.pedometer.queryStartEndHandler = { _, _, handler in handler(nil, nil) }
    }

    func testUnauthorizedReturnsError() {
        let promise = PedometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? PedometerSensor.PedometerError, .unauthorized)
        }
    }

    func testUnavailableReturnsError() {
        Current.pedometer.isAuthorized = { true }
        let promise = PedometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? PedometerSensor.PedometerError, .unavailable)
        }
    }

    func testNoDataReturnsError() {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        let promise = PedometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? PedometerSensor.PedometerError, .noData)
        }
    }

    func testQueryErrorsReturnsError() {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in hand(nil, TestError.someError) }

        let promise = PedometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, .someError)
        }
    }

    func testWithOnlyRequiredSteps() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in hand(FakePedometerData(), nil) }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].UniqueID, "pedometer_steps")
        XCTAssertEqual(sensors[0].Name, "Steps")
        XCTAssertEqual(sensors[0].Icon, "mdi:walk")
        XCTAssertEqual(sensors[0].UnitOfMeasurement, "steps")
        XCTAssertEqual(sensors[0].State as? Int, 0)
    }

    func testWithDistance() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideDistance = NSNumber(value: 123)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_distance" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_distance")
        XCTAssertEqual(sensor?.Name, "Distance")
        XCTAssertEqual(sensor?.Icon, "mdi:hiking")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "m")
        XCTAssertEqual(sensor?.State as? Int, 123)
    }

    func testWithFloorsAscendedBefore105() throws {
        request.serverVersion = Version(major: 0, minor: 104)
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideFloorsAscended = NSNumber(value: 234)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_floors_ascended" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_floors_ascended")
        XCTAssertEqual(sensor?.Name, "Floors Ascended")
        XCTAssertEqual(sensor?.Icon, "mdi:slope-uphill")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "floors")
        XCTAssertEqual(sensor?.State as? Int, 234)
    }

    func testWithFloorsAscendedAfter105() throws {
        request.serverVersion = Version(major: 0, minor: 105)
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideFloorsAscended = NSNumber(value: 234)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_floors_ascended" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_floors_ascended")
        XCTAssertEqual(sensor?.Name, "Floors Ascended")
        XCTAssertEqual(sensor?.Icon, "mdi:stairs-up")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "floors")
        XCTAssertEqual(sensor?.State as? Int, 234)
    }

    func testWithFloorsDescendedBefore105() throws {
        request.serverVersion = Version(major: 0, minor: 104)
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideFloorsDescended = NSNumber(value: 345)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_floors_descended" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_floors_descended")
        XCTAssertEqual(sensor?.Name, "Floors Descended")
        XCTAssertEqual(sensor?.Icon, "mdi:slope-downhill")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "floors")
        XCTAssertEqual(sensor?.State as? Int, 345)
    }

    func testWithFloorsDescendedAfter105() throws {
        request.serverVersion = Version(major: 0, minor: 105)
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideFloorsDescended = NSNumber(value: 345)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_floors_descended" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_floors_descended")
        XCTAssertEqual(sensor?.Name, "Floors Descended")
        XCTAssertEqual(sensor?.Icon, "mdi:stairs-down")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "floors")
        XCTAssertEqual(sensor?.State as? Int, 345)
    }

    func testWithAverageActivePace() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideAverageActivePace = NSNumber(value: 456)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_avg_active_pace" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_avg_active_pace")
        XCTAssertEqual(sensor?.Name, "Average Active Pace")
        XCTAssertEqual(sensor?.Icon, "mdi:speedometer")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "m/s")
        XCTAssertEqual(sensor?.State as? Int, 456)
    }

    func testWithCurrentPace() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideCurrentPace = NSNumber(value: 567)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_current_pace" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_current_pace")
        XCTAssertEqual(sensor?.Name, "Current Pace")
        XCTAssertEqual(sensor?.Icon, "mdi:speedometer")
        XCTAssertEqual(sensor?.UnitOfMeasurement, "m/s")
        XCTAssertEqual(sensor?.State as? Int, 567)
    }

    func testWithCurrentCadence() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in
            hand(with(FakePedometerData()) {
                $0.overrideCurrentCadence = NSNumber(value: 678)
            }, nil)
        }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        let sensor = sensors.first(where: { $0.UniqueID == "pedometer_current_cadence" })

        XCTAssertEqual(sensor?.UniqueID, "pedometer_current_cadence")
        XCTAssertEqual(sensor?.Name, "Current Cadence")
        XCTAssertEqual(sensor?.Icon, nil)
        XCTAssertEqual(sensor?.UnitOfMeasurement, "steps/s")
        XCTAssertEqual(sensor?.State as? Int, 678)
    }
}

private class FakePedometerData: CMPedometerData {
    var overrideNumberOfSteps = NSNumber(value: 0)
    override var numberOfSteps: NSNumber { overrideNumberOfSteps }
    var overrideDistance: NSNumber?
    override var distance: NSNumber? { overrideDistance }
    var overrideFloorsAscended: NSNumber?
    override var floorsAscended: NSNumber? { overrideFloorsAscended }
    var overrideFloorsDescended: NSNumber?
    override var floorsDescended: NSNumber? { overrideFloorsDescended }
    var overrideCurrentPace: NSNumber?
    override var currentPace: NSNumber? { overrideCurrentPace }
    var overrideCurrentCadence: NSNumber?
    override var currentCadence: NSNumber? { overrideCurrentCadence }
    var overrideAverageActivePace: NSNumber?
    override var averageActivePace: NSNumber? { overrideAverageActivePace }
}
