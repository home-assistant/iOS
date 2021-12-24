@testable import App
import XCTest
import XCTVapor

class AbstractTestCase: XCTestCase {
    // swiftlint:disable:next test_case_accessibility
    var app: Application!

    override func setUpWithError() throws {
        try super.setUpWithError()
        app = Application(.testing)
        try configure(app)
    }

    override func tearDown() {
        super.tearDown()
        app.shutdown()
    }
}
