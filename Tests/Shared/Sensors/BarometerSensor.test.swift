import CoreMotion
import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class BarometerSensorTests: XCTestCase {
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
        Current.barometer.isAuthorized = { false }
        Current.barometer.isAvailable = { false }
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in handler(nil, nil) }
        Current.barometer.stopUpdates = {}
    }

    func testUnauthorizedReturnsError() {
        let promise = BarometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? BarometerSensor.BarometerError, .unauthorized)
        }
    }

    func testUnavailableReturnsError() {
        Current.barometer.isAuthorized = { true }
        let promise = BarometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? BarometerSensor.BarometerError, .unavailable)
        }
    }

    func testNoDataReturnsError() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }
        let promise = BarometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? BarometerSensor.BarometerError, .noData)
        }
    }

    func testQueryErrorReturnsError() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in handler(nil, TestError.someError) }

        let promise = BarometerSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, .someError)
        }
    }

    func testStopUpdatesCalledAfterReading() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var stopUpdatesCalled = false
        Current.barometer.stopUpdates = { stopUpdatesCalled = true }
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in
            handler(FakeAltitudeData(pressureValue: 101.325), nil)
        }

        let promise = BarometerSensor(request: request).sensors()
        _ = try? hang(promise)
        XCTAssertTrue(stopUpdatesCalled)
    }

    func testPressureConvertedToHpa() throws {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }
        // CMAltitudeData.pressure is in kilopascals; 101.325 kPa = 1013.25 hPa
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in
            handler(FakeAltitudeData(pressureValue: 101.325), nil)
        }

        let promise = BarometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, WebhookSensorId.pressure.rawValue)
        XCTAssertEqual(sensors[0].Name, "Pressure")
        XCTAssertEqual(sensors[0].Icon, "mdi:gauge")
        XCTAssertEqual(sensors[0].DeviceClass, .pressure)
        XCTAssertEqual(sensors[0].UnitOfMeasurement, "hPa")
        XCTAssertEqual(sensors[0].State as? Double, 1013.25)
    }

    func testPressureRoundedToTwoDecimalPlaces() throws {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }
        // 98.7654 kPa * 10 = 987.654, rounded to 987.65
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in
            handler(FakeAltitudeData(pressureValue: 98.7654), nil)
        }

        let promise = BarometerSensor(request: request).sensors()
        let sensors = try hang(promise)

        XCTAssertEqual(sensors[0].State as? Double, 987.65)
    }
}

private class FakeAltitudeData: CMAltitudeData {
    private let pressureKpa: NSNumber

    init(pressureValue: Double) {
        self.pressureKpa = NSNumber(value: pressureValue)
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var pressure: NSNumber {
        pressureKpa
    }
}
