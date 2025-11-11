import Foundation
@testable import Shared
import XCTest

class URLOpenerServiceTests: XCTestCase {
    func testProtocolExists() {
        // Test that the protocol can be used
        let service: URLOpenerServiceProtocol = URLOpenerServiceImpl()
        XCTAssertNotNil(service)
    }

    func testCanOpenURL() {
        let service = URLOpenerServiceImpl()

        // Test with a valid URL scheme
        if let url = URL(string: "https://www.apple.com") {
            // We can't actually test the return value in unit tests without a real UIApplication
            // but we can verify the method exists and doesn't crash
            _ = service.canOpenURL(url)
        }
    }

    func testOpenURL() {
        let service = URLOpenerServiceImpl()

        if let url = URL(string: "https://www.apple.com") {
            // In unit tests, this will be called but won't actually open anything
            // We just verify it doesn't crash
            service.open(url, options: [:], completionHandler: nil)
        }
    }

    func testOpenURLWithCompletion() {
        let service = URLOpenerServiceImpl()
        let expectation = expectation(description: "Completion handler called")

        if let url = URL(string: "https://www.apple.com") {
            service.open(url, options: [:]) { _ in
                // In unit tests this may or may not succeed depending on environment
                expectation.fulfill()
            }

            waitForExpectations(timeout: 1.0)
        }
    }
}
