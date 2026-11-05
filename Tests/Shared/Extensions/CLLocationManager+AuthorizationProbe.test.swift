import CoreLocation
@testable import Shared
import XCTest

/// The probe exists so authorization can be read from any thread through a manager that was
/// created on the main thread; every thread must get that same manager.
final class CLLocationManagerAuthorizationProbeTests: XCTestCase {
    func testHandsOutTheSameManagerOnEveryThread() {
        let readOffMain = expectation(description: "read off the main thread")
        var offMain: CLLocationManager?
        DispatchQueue.global().async {
            offMain = CLLocationManager.authorizationProbe
            readOffMain.fulfill()
        }
        wait(for: [readOffMain], timeout: 5)

        let onMain = CLLocationManager.authorizationProbe

        XCTAssertNotNil(offMain)
        XCTAssertTrue(offMain === onMain)
        XCTAssertTrue(CLLocationManager.authorizationProbe === onMain)
    }
}
