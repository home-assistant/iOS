import Foundation
import PromiseKit
@testable import Shared
import XCTest

class HomeAssistantBackgroundTaskTests: XCTestCase {
    enum TestError: Error {
        case any
    }

    func testExpiredDeliversError() {
        let expectedIdentifier = 123_456
        let expectedRemaining: TimeInterval = 456

        let wrappingExpectation = expectation(description: "wrapping")
        let endExpectation = expectation(description: "endBackgroundTask")
        var expire: (() -> Void)?

        let promise: Promise<String> = HomeAssistantBackgroundTask.execute(
            withName: "name",
            beginBackgroundTask: { inName, inExpire -> (Int, TimeInterval) in
                XCTAssertEqual(inName, "name")
                expire = inExpire
                return (expectedIdentifier, expectedRemaining)
            }, endBackgroundTask: { (inIdentifier: Int) in
                if inIdentifier == expectedIdentifier {
                    endExpectation.fulfill()
                } else {
                    XCTFail("should not have called with identifier \(inIdentifier)")
                }
            }, wrapping: { givenRemaining in
                XCTAssertEqual(givenRemaining, expectedRemaining)
                wrappingExpectation.fulfill()
                return .value("hello!")
            }
        )

        expire?()

        // it still needs to tell to end the task
        wait(for: [endExpectation, wrappingExpectation], timeout: 10.0)

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? BackgroundTaskError, BackgroundTaskError.outOfTime)
        }
    }

    func testRejectedDeliversError() {
        let (underlyingPromise, underlyingSeal) = Promise<String>.pending()

        let endExpectedIdentifier = 123_456
        let expectedRemaining: TimeInterval = 456

        let wrappingExpectation = expectation(description: "wrapping")

        let endExpectation = expectation(description: "endBackgroundTask")

        let promise: Promise<String> = HomeAssistantBackgroundTask.execute(
            withName: "name",
            beginBackgroundTask: { inName, _ -> (Int, TimeInterval) in
                XCTAssertEqual(inName, "name")
                return (endExpectedIdentifier, expectedRemaining)
            }, endBackgroundTask: { (inIdentifier: Int) in
                if inIdentifier == endExpectedIdentifier {
                    endExpectation.fulfill()
                } else {
                    XCTFail("should not have called with identifier \(inIdentifier)")
                }
            }, wrapping: { givenRemaining in
                XCTAssertEqual(givenRemaining, expectedRemaining)
                wrappingExpectation.fulfill()
                return underlyingPromise
            }
        )

        underlyingSeal.reject(TestError.any)

        // it still needs to tell to end the task
        wait(for: [endExpectation, wrappingExpectation], timeout: 10.0)

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? TestError, TestError.any)
        }
    }

    func testFulfilledDeliversValue() throws {
        let (underlyingPromise, underlyingSeal) = Promise<String>.pending()

        let expectedIdentifier = 123_456
        let expectedRemaining: TimeInterval = 456

        let wrappingExpectation = expectation(description: "wrapping")
        let endExpectation = expectation(description: "endBackgroundTask")

        let promise: Promise<String> = HomeAssistantBackgroundTask.execute(
            withName: "name",
            beginBackgroundTask: { inName, _ -> (Int, TimeInterval) in
                XCTAssertEqual(inName, "name")
                return (expectedIdentifier, expectedRemaining)
            }, endBackgroundTask: { (inIdentifier: Int) in
                if inIdentifier == expectedIdentifier {
                    endExpectation.fulfill()
                } else {
                    XCTFail("should not have called with identifier \(inIdentifier)")
                }
            }, wrapping: { givenRemaining in
                XCTAssertEqual(givenRemaining, expectedRemaining)
                wrappingExpectation.fulfill()
                return underlyingPromise
            }
        )

        underlyingSeal.fulfill("dogs")

        // it still needs to tell to end the task
        wait(for: [endExpectation, wrappingExpectation], timeout: 10.0)

        XCTAssertEqual(try hang(promise), "dogs")
    }
}
