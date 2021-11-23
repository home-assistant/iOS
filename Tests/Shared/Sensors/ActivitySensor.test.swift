import CoreMotion
import Foundation
import PromiseKit
@testable import Shared
import Version
import XCTest

class ActivitySensorTests: XCTestCase {
    private enum TestError: Error {
        case someError
    }

    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func setUp() {
        super.setUp()

        // start by assuming nothing is enabled/available
        Current.motion.isAuthorized = { false }
        Current.motion.isActivityAvailable = { false }
        Current.motion.queryStartEndOnQueueHandler = { _, _, _, handler in handler([], nil) }
    }

    func testUnauthorizedReturnsError() {
        let promise = ActivitySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? ActivitySensor.ActivityError, .unauthorized)
        }
    }

    func testUnavailableReturnsError() {
        Current.motion.isAuthorized = { true }
        let promise = ActivitySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? ActivitySensor.ActivityError, .unavailable)
        }
    }

    func testNoDataReturnsError() {
        Current.motion.isAuthorized = { true }
        Current.motion.isActivityAvailable = { true }
        let promise = ActivitySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? ActivitySensor.ActivityError, .noData)
        }
    }

    func testQueryReturnsContractuallyImpossibleErrorReturnsError() {
        Current.motion.isAuthorized = { true }
        Current.motion.isActivityAvailable = { true }
        Current.motion.queryStartEndOnQueueHandler = { _, _, _, handler in handler(nil, nil) }

        let promise = ActivitySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? ActivitySensor.ActivityError, .noData)
        }
    }

    func testQueryErrorsReturnsError() {
        Current.motion.isAuthorized = { true }
        Current.motion.isActivityAvailable = { true }
        Current.motion.queryStartEndOnQueueHandler = { _, _, _, hand in hand(nil, TestError.someError) }

        let promise = ActivitySensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, .someError)
        }
    }

    func testQuerySucceedsReturnsSensor() throws {
        let anyActivity = with(FakeMotionActivity()) {
            $0.walking = true
        }

        Current.motion.isAuthorized = { true }
        Current.motion.isActivityAvailable = { true }
        Current.motion.queryStartEndOnQueueHandler = { _, _, _, hand in hand([anyActivity], nil) }

        let promise = ActivitySensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].Name, "Activity")
        XCTAssertEqual(sensors[0].UniqueID, "activity")
    }

    func testQueryActivitiesReturnSensors() throws {
        Current.motion.isAuthorized = { true }
        Current.motion.isActivityAvailable = { true }

        let testCases: [(FakeMotionActivity) -> Void] = [
            { $0.walking = true },
            { $0.running = true },
            { $0.automotive = true },
            { $0.cycling = true },
            { $0.stationary = true },
            { $0.walking = true; $0.running = true },
            { $0.running = true; $0.automotive = true },
            { $0.automotive = true; $0.cycling = true },
            { $0.cycling = true; $0.stationary = true },
            { $0.walking = true; $0.confidence = .low },
            { $0.walking = true; $0.confidence = .medium },
            { $0.walking = true; $0.confidence = .high },
        ]

        for testCase in testCases {
            let activity = with(FakeMotionActivity()) { testCase($0) }
            Current.motion.queryStartEndOnQueueHandler = { _, _, _, handler in handler([activity], nil) }

            let promise = ActivitySensor(request: request).sensors()
            let sensors = try hang(promise)
            XCTAssertEqual(sensors.count, 1)
            XCTAssertEqual(sensors[0].State as? String, activity.activityTypes.first)
            XCTAssertEqual(sensors[0].Icon, activity.icons.first)
            XCTAssertEqual(sensors[0].Attributes?["Confidence"] as? String, activity.confidence.description)
            XCTAssertEqual(sensors[0].Attributes?["Types"] as? [String], activity.activityTypes)
        }
    }
}

private class FakeMotionActivity: CMMotionActivity {
    private var underlyingWalking = false
    override var walking: Bool {
        get { underlyingWalking }
        set { underlyingWalking = newValue }
    }

    private var underlyingRunning = false
    override var running: Bool {
        get { underlyingRunning }
        set { underlyingRunning = newValue }
    }

    private var underlyingAutomotive = false
    override var automotive: Bool {
        get { underlyingAutomotive }
        set { underlyingAutomotive = newValue }
    }

    private var underlyingCycling = false
    override var cycling: Bool {
        get { underlyingCycling }
        set { underlyingCycling = newValue }
    }

    private var underlyingStationary = false
    override var stationary: Bool {
        get { underlyingStationary }
        set { underlyingStationary = newValue }
    }

    private var underlyingConfidence: CMMotionActivityConfidence = .low
    override var confidence: CMMotionActivityConfidence {
        get { underlyingConfidence }
        set { underlyingConfidence = newValue }
    }
}
