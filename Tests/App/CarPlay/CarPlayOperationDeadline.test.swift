@testable import HomeAssistant
@testable import Shared
import XCTest

final class CarPlayOperationDeadlineTests: XCTestCase {
    /// `ServerFixture.standard` carries no reachable URL, so `Current.api(for:)` yields nil and any
    /// failure resolves to `.noConnection` — the case a car in a dead zone actually hits.
    private let server = ServerFixture.standard

    func testReportsSuccessWhenTheActionCompletes() {
        let reported = expectation(description: "outcome reported")
        var outcome: CarPlayOperationError?
        var reportCount = 0

        let deadline = CarPlayOperationDeadline(server: server, timeout: 60) { error in
            outcome = error
            reportCount += 1
            reported.fulfill()
        }
        deadline.succeed()

        wait(for: [reported], timeout: 1)
        XCTAssertNil(outcome)
        XCTAssertEqual(reportCount, 1)
    }

    func testReportsFailureWhenTheActionReportsAnError() {
        let reported = expectation(description: "outcome reported")
        var outcome: CarPlayOperationError?

        let deadline = CarPlayOperationDeadline(server: server, timeout: 60) { error in
            outcome = error
            reported.fulfill()
        }
        deadline.fail(CarPlayOperationDeadlineTestError.any)

        wait(for: [reported], timeout: 1)
        XCTAssertNotNil(outcome)
    }

    /// The point of the deadline: HAKit queues a request while the connection is down and never
    /// expires it, so an action that is never answered still has to settle.
    func testReportsFailureWhenTheActionNeverAnswers() {
        let reported = expectation(description: "outcome reported")
        var outcome: CarPlayOperationError?

        _ = CarPlayOperationDeadline(server: server, timeout: 0.1) { error in
            outcome = error
            reported.fulfill()
        }

        wait(for: [reported], timeout: 2)
        guard let outcome, case .noConnection = outcome else {
            XCTFail("Expected .noConnection, got \(String(describing: outcome))")
            return
        }
    }

    func testIgnoresAReplyThatArrivesAfterTheDeadlineFired() {
        let reported = expectation(description: "outcome reported")
        var reportCount = 0

        let deadline = CarPlayOperationDeadline(server: server, timeout: 0.1) { _ in
            reportCount += 1
            reported.fulfill()
        }

        wait(for: [reported], timeout: 2)
        deadline.succeed()

        let settled = expectation(description: "no further report")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settled.fulfill()
        }
        wait(for: [settled], timeout: 2)
        XCTAssertEqual(reportCount, 1)
    }

    func testReportsOnlyTheFirstOutcome() {
        let reported = expectation(description: "outcome reported")
        var outcome: CarPlayOperationError?
        var reportCount = 0

        let deadline = CarPlayOperationDeadline(server: server, timeout: 60) { error in
            outcome = error
            reportCount += 1
            reported.fulfill()
        }
        deadline.succeed()
        deadline.fail(CarPlayOperationDeadlineTestError.any)

        wait(for: [reported], timeout: 1)
        XCTAssertNil(outcome)
        XCTAssertEqual(reportCount, 1)
    }
}

private enum CarPlayOperationDeadlineTestError: Error {
    case any
}
