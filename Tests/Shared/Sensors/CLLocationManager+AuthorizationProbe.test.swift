import CoreLocation
import HAKit
@testable import Shared
import XCTest

/// The probe exists so authorization can be read from any thread through a manager that was
/// created on the main thread, and every thread must get that same manager.
final class CLLocationManagerAuthorizationProbeTests: XCTestCase {
    private var storage: HAProtected<CLLocationManager?>!
    private var builtOnMainThread: [Bool]!

    override func setUp() {
        super.setUp()
        storage = HAProtected<CLLocationManager?>(value: nil)
        builtOnMainThread = []
    }

    override func tearDown() {
        storage = nil
        builtOnMainThread = nil
        super.tearDown()
    }

    private func make() -> CLLocationManager {
        builtOnMainThread.append(Thread.isMainThread)
        return CLLocationManager()
    }

    func testAFirstAccessOffTheMainThreadBuildsOnMain() {
        let readOffMain = expectation(description: "read off the main thread")
        var offMain: CLLocationManager?
        DispatchQueue.global().async { [self] in
            offMain = CLLocationManager.authorizationProbe(in: storage, make: make)
            readOffMain.fulfill()
        }
        wait(for: [readOffMain], timeout: 5)

        XCTAssertEqual(builtOnMainThread, [true])
        XCTAssertTrue(storage.read { $0 } === offMain)
    }

    func testAFirstAccessOnTheMainThreadBuildsInPlace() {
        let onMain = CLLocationManager.authorizationProbe(in: storage, make: make)

        XCTAssertEqual(builtOnMainThread, [true])
        XCTAssertTrue(storage.read { $0 } === onMain)
    }

    func testLaterAccessesReuseTheStoredManager() {
        let first = CLLocationManager.authorizationProbe(in: storage, make: make)
        let second = CLLocationManager.authorizationProbe(in: storage, make: make)

        XCTAssertTrue(first === second)
        XCTAssertEqual(builtOnMainThread.count, 1)
    }

    func testTheFirstManagerStoredWinsARace() {
        // A factory that loses the race: by the time it returns, another thread has stored its own.
        let winner = CLLocationManager()
        let loser = CLLocationManager.authorizationProbe(in: storage) { [storage] in
            storage?.mutate { $0 = winner }
            return CLLocationManager()
        }

        XCTAssertTrue(loser === winner)
        XCTAssertTrue(storage.read { $0 } === winner)
    }

    func testTheSharedProbeHandsOutOneManagerOnEveryThread() {
        let readOffMain = expectation(description: "read off the main thread")
        var offMain: CLLocationManager?
        DispatchQueue.global().async {
            offMain = CLLocationManager.authorizationProbe
            readOffMain.fulfill()
        }
        wait(for: [readOffMain], timeout: 5)

        XCTAssertTrue(offMain === CLLocationManager.authorizationProbe)
    }
}
