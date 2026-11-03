import CoreMotion
import Foundation
import PromiseKit
@testable import Shared
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

    /// Listed rather than dropped: switching one on is what asks for motion access, so sensors
    /// that vanished until it was granted would have no row left to switch on.
    func testUnauthorizedReportsUnavailable() throws {
        Current.pedometer.isStepCountingAvailable = { true }

        let sensors = try hang(PedometerSensor(request: request).sensors())
        XCTAssertEqual(Set(sensors.compactMap(\.UniqueID)), Set(PedometerSensor.allSensorIDs))
        for sensor in sensors {
            XCTAssertEqual(sensor.State as? String, "unavailable", sensor.UniqueID ?? "")
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

    /// A sensor only reported when it has a value has no row in the sensor list the rest of the
    /// time, and so nothing to switch off. Current pace and cadence never have one from the daily
    /// query, so dropping them is what left their entities with no toggle anywhere in the app.
    func testEverySensorIsListedEvenWithoutAValue() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in hand(FakePedometerData(), nil) }

        for reason in [SensorProviderRequest.Reason.trigger("unit-test"), .registration] {
            request.reason = reason
            let sensors = try hang(PedometerSensor(request: request).sensors())

            XCTAssertEqual(Set(sensors.compactMap(\.UniqueID)), Set(PedometerSensor.allSensorIDs), "\(reason)")
            for sensor in sensors where sensor.UniqueID != "pedometer_steps" {
                XCTAssertEqual(sensor.State as? String, "unavailable", "\(reason) \(sensor.UniqueID ?? "")")
            }
            let pace = sensors.first(where: { $0.UniqueID == "pedometer_current_pace" })
            XCTAssertEqual(pace?.Name, "Current Pace", "\(reason)")
            XCTAssertEqual(pace?.UnitOfMeasurement, "m/s", "\(reason)")
            let cadence = sensors.first(where: { $0.UniqueID == "pedometer_current_cadence" })
            XCTAssertEqual(cadence?.Name, "Current Cadence", "\(reason)")
            XCTAssertEqual(cadence?.UnitOfMeasurement, "steps/s", "\(reason)")
        }
    }

    func testWithOnlyRequiredSteps() throws {
        Current.pedometer.isAuthorized = { true }
        Current.pedometer.isStepCountingAvailable = { true }
        Current.pedometer.queryStartEndHandler = { _, _, hand in hand(FakePedometerData(), nil) }

        let promise = PedometerSensor(request: request).sensors()
        let sensors = try hang(promise)
        let steps = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "pedometer_steps" }))

        XCTAssertEqual(steps.Name, "Steps")
        XCTAssertEqual(steps.Icon, "mdi:walk")
        XCTAssertEqual(steps.UnitOfMeasurement, "steps")
        XCTAssertEqual(steps.State as? Int, 0)
        XCTAssertEqual(steps.StateClass, .totalIncreasing)
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
        XCTAssertEqual(sensor?.StateClass, .totalIncreasing)
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
        XCTAssertEqual(sensor?.StateClass, .totalIncreasing)
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
        XCTAssertEqual(sensor?.StateClass, .measurement)
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
        XCTAssertEqual(sensor?.StateClass, .measurement)
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
