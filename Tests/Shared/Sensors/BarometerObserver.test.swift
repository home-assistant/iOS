import CoreMotion
import Foundation
@testable import Shared
import XCTest

class BarometerObserverTests: XCTestCase {
    private var observer: BarometerObserver!

    override func setUp() {
        super.setUp()

        Current.barometer.isAuthorized = { true }
        Current.barometer.isAvailable = { true }
        Current.barometer.startUpdatesOnQueueHandler = { _, handler in handler(nil, nil) }
        Current.barometer.stopUpdates = {}

        observer = BarometerObserver()
    }

    override func tearDown() {
        observer = nil
        super.tearDown()
    }

    func testFirstSubscriberStartsSessionAndSecondReusesIt() {
        var startCount = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCount += 1 }

        XCTAssertTrue(observer.addSubscriber(id: "a", handler: { _, _ in }))
        XCTAssertEqual(startCount, 1)

        XCTAssertTrue(observer.addSubscriber(id: "b", handler: { _, _ in }))
        XCTAssertEqual(startCount, 1)
    }

    func testEverySubscriberReceivesEveryReading() {
        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, registered in handler = registered }

        var pressuresA = [Double]()
        var pressuresB = [Double]()
        observer.addSubscriber(id: "a", handler: { data, _ in pressuresA.append(data?.pressure.doubleValue ?? 0) })
        observer.addSubscriber(id: "b", handler: { data, _ in pressuresB.append(data?.pressure.doubleValue ?? 0) })

        handler?(FakeAltitudeData(pressureValue: 101.3), nil)
        handler?(FakeAltitudeData(pressureValue: 78.5), nil)

        XCTAssertEqual(pressuresA, [101.3, 78.5])
        XCTAssertEqual(pressuresB, [101.3, 78.5])
    }

    func testErrorsAreForwardedToSubscribers() {
        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, registered in handler = registered }

        var receivedError: Error?
        observer.addSubscriber(id: "a", handler: { _, error in receivedError = error })

        handler?(nil, TestError.someError)
        XCTAssertEqual(receivedError as? TestError, .someError)
    }

    func testSessionStopsOnlyWhenLastSubscriberLeaves() {
        var stopCount = 0
        Current.barometer.stopUpdates = { stopCount += 1 }

        observer.addSubscriber(id: "a", handler: { _, _ in })
        observer.addSubscriber(id: "b", handler: { _, _ in })

        observer.removeSubscriber(id: "a")
        XCTAssertEqual(stopCount, 0)

        observer.removeSubscriber(id: "b")
        XCTAssertEqual(stopCount, 1)
    }

    func testSessionRestartsAfterAllSubscribersLeft() {
        var startCount = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCount += 1 }

        observer.addSubscriber(id: "a", handler: { _, _ in })
        observer.removeSubscriber(id: "a")
        observer.addSubscriber(id: "a", handler: { _, _ in })

        XCTAssertEqual(startCount, 2)
    }

    func testLatestPressureIsCachedWhileRunningAndClearedOnStop() {
        var handler: CMAltitudeHandler?
        Current.barometer.startUpdatesOnQueueHandler = { _, registered in handler = registered }

        observer.addSubscriber(id: "a", handler: { _, _ in })
        XCTAssertNil(observer.latestPressureKpa)

        handler?(FakeAltitudeData(pressureValue: 99.5), nil)
        XCTAssertEqual(observer.latestPressureKpa, 99.5)

        observer.removeSubscriber(id: "a")
        XCTAssertNil(observer.latestPressureKpa)
    }

    func testUnauthorizedSubscriptionIsRejectedWithoutStartingASession() {
        Current.barometer.isAuthorized = { false }

        var startCount = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCount += 1 }

        XCTAssertFalse(observer.addSubscriber(id: "a", handler: { _, _ in }))
        XCTAssertFalse(observer.hasSubscriber(id: "a"))
        XCTAssertEqual(startCount, 0)
    }

    func testUnavailableSubscriptionIsRejectedWithoutStartingASession() {
        Current.barometer.isAvailable = { false }

        var startCount = 0
        Current.barometer.startUpdatesOnQueueHandler = { _, _ in startCount += 1 }

        XCTAssertFalse(observer.addSubscriber(id: "a", handler: { _, _ in }))
        XCTAssertEqual(startCount, 0)
    }

    private enum TestError: Error {
        case someError
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
