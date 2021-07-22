import CoreLocation
import Foundation
import PromiseKit
@testable import Shared
import XCGLogger
import XCTest

class OneShotLocationTests: XCTestCase {
    private var locationManager: FakeLocationManager!
    private var now: Date!

    override func setUp() {
        let now = Date()
        self.now = now
        Current.date = { now }
        locationManager = FakeLocationManager()
    }

    override func tearDown() {
        XCTAssertNil(locationManager.delegate)
        XCTAssertFalse(locationManager.isUpdatingLocation)
    }

    func testNoLocationsNoErrorJustTimeout() {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        timeoutSeal(())
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? OneShotError, OneShotError.outOfTime)
        }
    }

    func testNoLocationsOnlyCLError() {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        let clError = CLError(.deferredAccuracyTooLow)
        locationManager.delegate?.locationManager?(locationManager, didFailWithError: clError)
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? OneShotError, OneShotError.clError(clError))
        }
    }

    func testNoLocationsOnlyRandomError() {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        enum SomeError: Error {
            case yep
        }

        locationManager.delegate?.locationManager?(locationManager, didFailWithError: SomeError.yep)
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? SomeError, SomeError.yep)
        }
    }

    func testOnlyCachedLocationNoErrorsOnlyTimeout() throws {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let cachedLocation = CLLocation(latitude: 123, longitude: -123)
        locationManager.cachedLocation = cachedLocation
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        timeoutSeal(())
        XCTAssertEqual(try hang(promise), cachedLocation)
    }

    func testOnlyCachedLocationError() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let cachedLocation = CLLocation(latitude: 123, longitude: -123)
        locationManager.cachedLocation = cachedLocation
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didFailWithError: CLError(.deferredAccuracyTooLow))
        XCTAssertEqual(try hang(promise), cachedLocation)
    }

    func testOldCachedAndOneLocationNoError() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let cachedLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-500)
        )
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        locationManager.cachedLocation = cachedLocation
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [newLocation])
        XCTAssertEqual(try hang(promise), newLocation)
    }

    func testNoCachedValueAndOneLocationNoError() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [newLocation])
        XCTAssertEqual(try hang(promise), newLocation)
    }

    func testNoCachedValueOneLocationAndError() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [newLocation])
        locationManager.delegate?.locationManager?(locationManager, didFailWithError: CLError(.deferredAccuracyTooLow))
        XCTAssertEqual(try hang(promise), newLocation)
    }

    func testOneNewOneOldLocationWithPerfectAgeAndAccuracyOldestFirst() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-100)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1, location2])
        XCTAssertEqual(try hang(promise), location2)
    }

    func testOneNewOneOldLocationWithPerfectAgeAndAccuracyNewestFirst() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-100)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location2, location1])
        XCTAssertEqual(try hang(promise), location2)
    }

    func testMultiplePerfectNoError() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-5)
        )
        let location3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -12, longitude: 12),
            altitude: 0,
            horizontalAccuracy: 0,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-1)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [
            location3, location1, location2,
        ])
        XCTAssertEqual(try hang(promise), location3)
    }

    func testNoPerfectOnlyPoorChoicesOnAccuracyUntilTimeout() throws {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 2500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-100)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let location3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -12, longitude: 12),
            altitude: 0,
            horizontalAccuracy: 600,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-30)
        )
        let location4 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -23, longitude: 23),
            altitude: 0,
            horizontalAccuracy: 600,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-40)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [
            location1, location2, location3, location4,
        ])
        XCTAssertFalse(promise.isResolved, "it shouldn't end early just because it got some")

        timeoutSeal(())
        XCTAssertEqual(try hang(promise), location2)
    }

    func testNoPerfectOnlyPoorChoicesOnAgeUntilTimeout() throws {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-160)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-150)
        )
        let location3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -12, longitude: 12),
            altitude: 0,
            horizontalAccuracy: 400,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-120)
        )
        let location4 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -23, longitude: 23),
            altitude: 0,
            horizontalAccuracy: 250,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-100)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [
            location1, location2, location3, location4,
        ])
        XCTAssertFalse(promise.isResolved, "it shouldn't end early just because it got some")

        timeoutSeal(())
        XCTAssertEqual(try hang(promise), location1)
    }

    func testInvalidAgeOnlyUntilTimeout() {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-666)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-601)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1])
        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location2])
        timeoutSeal(())

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? OneShotError, OneShotError.outOfTime)
        }
    }

    func testInvalidAccuracyOnlyUntilTimeout() {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 1501,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-30)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 2500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-5)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1])
        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location2])
        timeoutSeal(())

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? OneShotError, OneShotError.outOfTime)
        }
    }

    @available(iOS 14, *)
    func testInvalidAccuracyOnlyUntilTimeoutWhenReducedAccuracy() {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 1501,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-30)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 2500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-5)
        )

        locationManager.overrideAccuracyAuthorization = .reducedAccuracy

        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1])
        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location2])
        timeoutSeal(())

        XCTAssertEqual(try hang(promise), location1)
    }

    func testInvalidLatOrLongOnlyUntilTimeout() {
        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-20)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: 0),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let location3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -0, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-5)
        )
        let location4 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -0),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(0)
        )
        let location5 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: Double.leastNonzeroMagnitude),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(0)
        )
        let location6 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: Double.leastNonzeroMagnitude, longitude: 123),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(0)
        )
        let location7 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -Double.leastNonzeroMagnitude),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(0)
        )
        let location8 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -Double.leastNonzeroMagnitude, longitude: 123),
            altitude: 0,
            horizontalAccuracy: 200,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(0)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [
            location1, location2, location3, location4,
            location5, location6, location7, location8,
        ])
        timeoutSeal(())

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? OneShotError, OneShotError.outOfTime)
        }
    }

    func testMultipleAccuracyThenPerfect() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
            altitude: 0,
            horizontalAccuracy: 2500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-500)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
            altitude: 0,
            horizontalAccuracy: 1500,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-450)
        )
        let location3 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 23, longitude: -23),
            altitude: 0,
            horizontalAccuracy: 1000,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-400)
        )
        let location4 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -12, longitude: 12),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-10)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1, location2])
        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location4, location3])
        XCTAssertEqual(try hang(promise), location4)
    }

    func testUnsanitizableLocationInvalid() {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: .infinity, longitude: 2),
            altitude: 0,
            horizontalAccuracy: 20, // normally would win
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-20)
        )
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 3),
            altitude: 0,
            horizontalAccuracy: 100, // normally would lose
            verticalAccuracy: 0,
            timestamp: now.addingTimeInterval(-30)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1, location2])

        XCTAssertEqual(try hang(promise), location2)
    }

    func testSanitizableLocation() throws {
        let (timeoutPromise, _) = Guarantee<Void>.pending()
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 2),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: .infinity,
            timestamp: now.addingTimeInterval(-20)
        )
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: [location1])

        let result = try hang(promise)
        XCTAssertEqual(result.coordinate.latitude, 1)
        XCTAssertEqual(result.coordinate.longitude, 2)
        XCTAssertEqual(result.verticalAccuracy, -1)
    }

    struct LocationTestCase {
        let location1: CLLocation
        let location2: CLLocation
        var winnerLocation: CLLocation { location2 }
        let reason: String
        let hasPerfect: Bool

        let file: StaticString
        let line: UInt

        // second one always is the winner, order is done both ways to make sure logic is fine
        init(
            age1: TimeInterval, acc1: CLLocationAccuracy,
            age2: TimeInterval, acc2: CLLocationAccuracy,
            _ reason: String,
            file: StaticString = #file,
            line: UInt = #line
        ) {
            let location1 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 12, longitude: -12),
                altitude: 0,
                horizontalAccuracy: acc1,
                verticalAccuracy: 0,
                timestamp: Current.date().addingTimeInterval(-age1)
            )
            let location2 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 123, longitude: -123),
                altitude: 0,
                horizontalAccuracy: acc2,
                verticalAccuracy: 0,
                timestamp: Current.date().addingTimeInterval(-age2)
            )
            self.location1 = location1
            self.location2 = location2
            // cheating a little so it's not constants hard-coded in two places
            self.hasPerfect =
                PotentialLocation(location: location1, accuracyAuthorization: .fullAccuracy).quality == .perfect ||
                PotentialLocation(location: location2, accuracyAuthorization: .fullAccuracy).quality == .perfect
            self.reason = reason
            self.file = file
            self.line = line
        }
    }

    func testBothPerfectForward() {
        perform(
            testCase: .init(age1: 5, acc1: 90, age2: 0, acc2: 100, "both perfect, more recent wins"),
            forward: true
        )
    }

    func testBothPerfectBackward() {
        perform(
            testCase: .init(age1: 5, acc1: 90, age2: 0, acc2: 100, "both perfect, more recent wins"),
            forward: false
        )
    }

    func testOnePerfectForward() {
        perform(
            testCase: .init(age1: 0, acc1: 2500, age2: 10, acc2: 100, "one perfect, always wins"),
            forward: true
        )
    }

    func testOnePerfectBackward() {
        perform(
            testCase: .init(age1: 0, acc1: 2500, age2: 10, acc2: 100, "one perfect, always wins"),
            forward: false
        )
    }

    func testCloseTimingForward() {
        perform(
            testCase: .init(age1: 35, acc1: 500, age2: 40, acc2: 250, "close timing, more accurate wins"),
            forward: true
        )
    }

    func testCloseTimingBackward() {
        perform(
            testCase: .init(age1: 35, acc1: 500, age2: 40, acc2: 250, "close timing, more accurate wins"),
            forward: false
        )
    }

    func testMoreRecentWinsForward() {
        perform(
            testCase: .init(age1: 120, acc1: 100, age2: 35, acc2: 1000, "much more recent wins, even over accuracy"),
            forward: true
        )
    }

    func testMoreRecentWinsBackward() {
        perform(
            testCase: .init(age1: 120, acc1: 100, age2: 35, acc2: 1000, "much more recent wins, even over accuracy"),
            forward: false
        )
    }

    func perform(testCase: LocationTestCase, forward: Bool) {
        let locations = forward ? [testCase.location1, testCase.location2] : [testCase.location2, testCase.location1]

        let (timeoutPromise, timeoutSeal) = Guarantee<Void>.pending()
        let promise = OneShotLocationProxy(
            locationManager: locationManager,
            timeout: timeoutPromise
        ).promise

        locationManager.delegate?.locationManager?(locationManager, didUpdateLocations: locations)

        if testCase.hasPerfect {
            XCTAssertEqual(
                try hang(promise),
                testCase.winnerLocation,
                testCase.reason,
                file: testCase.file,
                line: testCase.line
            )
        } else {
            XCTAssertFalse(promise.isFulfilled, file: testCase.file, line: testCase.line)
            timeoutSeal(())

            XCTAssertEqual(
                try hang(promise),
                testCase.winnerLocation,
                testCase.reason,
                file: testCase.file,
                line: testCase.line
            )
        }
    }
}

private class FakeLocationManager: CLLocationManager {
    var cachedLocation: CLLocation?
    override var location: CLLocation? {
        cachedLocation
    }

    var overrideDelegate: CLLocationManagerDelegate?
    override var delegate: CLLocationManagerDelegate? {
        get {
            overrideDelegate
        }
        set {
            overrideDelegate = newValue
        }
    }

    var overrideAccuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    override var accuracyAuthorization: CLAccuracyAuthorization {
        overrideAccuracyAuthorization
    }

    var overrideAuthorizationStatus: CLAuthorizationStatus = .authorizedAlways
    override var authorizationStatus: CLAuthorizationStatus {
        overrideAuthorizationStatus
    }

    var isUpdatingLocation = false
    override func startUpdatingLocation() {
        isUpdatingLocation = true
    }

    override func stopUpdatingLocation() {
        isUpdatingLocation = false
    }

    override var allowsBackgroundLocationUpdates: Bool {
        get { false }
        set {}
    }
}
