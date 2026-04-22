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
    private var originalSensors: SensorContainer!

    override func setUp() {
        super.setUp()

        // Reset sensor container to prevent leftover lastUpdate from previous tests
        // from triggering BaseSensorUpdateSignaler's observer path during init.
        // Saved and restored in tearDown so we don't strip the registered providers
        // that other test classes rely on.
        originalSensors = Current.sensors
        Current.sensors = SensorContainer()

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

    override func tearDown() {
        Current.sensors = originalSensors
        originalSensors = nil
        super.tearDown()
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
        XCTAssertNoThrow(try hang(promise))
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

    func testSensorsUsesCachedDataWhenSignalerIsActive() throws {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        // Capture every handler that gets registered, since BaseSensorUpdateSignaler's
        // observer registration may trigger observe() and register a handler before
        // our explicit call does.
        var handlers = [CMAltitudeHandler]()
        var startCountAfterSetup = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, h in handlers.append(h) }
        Current.barometer.stopUpdates = {}

        let sensor = BarometerSensor(request: request)
        let signaler: BarometerSensorUpdateSignaler = request.dependencies.updateSignaler(for: sensor)
        signaler.observe()

        // Deliver data to the most recently registered handler
        guard let latestHandler = handlers.last else {
            XCTFail("No handler was registered")
            return
        }
        latestHandler(FakeAltitudeData(pressureValue: 101.0), nil)
        XCTAssertNotNil(signaler.latestPressureKpa)

        // Reset to track whether sensors() starts another read
        startCountAfterSetup = handlers.count
        let promise = sensor.sensors()
        let sensors = try hang(promise)

        XCTAssertEqual(sensors[0].State as? Double, 1010.0) // 101.0 kPa * 10
        // Should NOT have started another altimeter session
        XCTAssertEqual(handlers.count, startCountAfterSetup)
    }

    func testSignalerStartsAndStopsUpdates() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var startCalled = false
        var stopCalled = false
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCalled = true }
        Current.barometer.stopUpdates = { stopCalled = true }

        var signalCount = 0
        let signaler = BarometerSensorUpdateSignaler(signal: { signalCount += 1 })

        signaler.observe()
        XCTAssertTrue(startCalled)

        signaler.stopObserving()
        XCTAssertTrue(stopCalled)
    }

    func testSignalerClearsDataOnStop() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, h in handler = h }
        Current.barometer.stopUpdates = {}

        let signaler = BarometerSensorUpdateSignaler(signal: {})
        signaler.observe()
        handler?(FakeAltitudeData(pressureValue: 101.0), nil)
        XCTAssertNotNil(signaler.latestPressureKpa)

        signaler.stopObserving()
        XCTAssertNil(signaler.latestPressureKpa)
    }

    func testSignalerFiltersSmallPressureChanges() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, h in handler = h }
        Current.barometer.stopUpdates = {}

        var signalCount = 0
        let signaler = BarometerSensorUpdateSignaler(signal: { signalCount += 1 })
        signaler.observe()

        // First reading always signals
        handler?(FakeAltitudeData(pressureValue: 101.325), nil)
        XCTAssertEqual(signalCount, 1)

        // Tiny change (< 0.01 kPa = < 0.1 hPa) should not signal
        handler?(FakeAltitudeData(pressureValue: 101.330), nil)
        XCTAssertEqual(signalCount, 1)

        // Significant change (>= 0.01 kPa = >= 0.1 hPa) should signal
        handler?(FakeAltitudeData(pressureValue: 101.340), nil)
        XCTAssertEqual(signalCount, 2)
    }

    func testSignalerIgnoresNilData() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, h in handler = h }
        Current.barometer.stopUpdates = {}

        var signalCount = 0
        let signaler = BarometerSensorUpdateSignaler(signal: { signalCount += 1 })
        signaler.observe()

        // nil data should not signal or cache
        handler?(nil, nil)
        XCTAssertEqual(signalCount, 0)
        XCTAssertNil(signaler.latestPressureKpa)
    }

    func testSignalerDoesNotStartWhenUnavailable() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { false }

        var startCalled = false
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCalled = true }

        let signaler = BarometerSensorUpdateSignaler(signal: {})
        signaler.observe()
        XCTAssertFalse(startCalled)
    }

    func testSignalerDoesNotStartWhenUnauthorized() {
        Current.barometer.isAuthorized = { false }
        Current.barometer.isAvailable = { true }

        var startCalled = false
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCalled = true }

        let signaler = BarometerSensorUpdateSignaler(signal: {})
        signaler.observe()
        XCTAssertFalse(startCalled)
    }

    func testSignalerDoesNotDoubleObserve() {
        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }

        var startCount = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCount += 1 }
        Current.barometer.stopUpdates = {}

        let signaler = BarometerSensorUpdateSignaler(signal: {})
        signaler.observe()
        signaler.observe()
        XCTAssertEqual(startCount, 1)
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

    override var relativeAltitude: NSNumber {
        NSNumber(value: 0)
    }
}
