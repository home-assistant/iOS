import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

/// The rate limit screen shows the push server's counters, counting down to the daily UTC reset.
@MainActor
final class NotificationRateLimitViewModelTests: XCTestCase {
    private var previousPushID: String?

    override func setUp() async throws {
        previousPushID = Current.settingsStore.pushID
        // Without a push ID nothing is requested from the push server.
        Current.settingsStore.pushID = nil
    }

    override func tearDown() async throws {
        Current.settingsStore.pushID = previousPushID
    }

    private func makeResponse(remaining: Int = 280) -> RateLimitResponse {
        RateLimitResponse(
            target: "push-target",
            rateLimits: .init(
                attempts: 25,
                successful: 20,
                errors: 5,
                total: 25,
                maximum: 300,
                remaining: remaining,
                resetsAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
    }

    func testStartsLoading() {
        let viewModel = NotificationRateLimitViewModel(initialPromise: nil)

        guard case .loading = viewModel.state else {
            return XCTFail("Expected the loading state, got \(viewModel.state)")
        }
        XCTAssertNil(viewModel.resetsInText)
        XCTAssertFalse(viewModel.isRefreshing)
    }

    func testRefreshUsesTheInitialPromiseAndReportsTheResponse() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .value(makeResponse(remaining: 123)))
        var reportedRemaining: Int?
        viewModel.onChange = { reportedRemaining = $0.rateLimits.remaining }

        await viewModel.refreshIfNeeded()

        guard case let .loaded(response) = viewModel.state else {
            return XCTFail("Expected the loaded state, got \(viewModel.state)")
        }
        XCTAssertEqual(response.target, "push-target")
        XCTAssertEqual(response.rateLimits.remaining, 123)
        XCTAssertEqual(reportedRemaining, 123)
        XCTAssertNotNil(viewModel.resetsInText)
        XCTAssertFalse(viewModel.isRefreshing)
    }

    /// Once loaded, appearing again doesn't reload.
    func testRefreshIfNeededOnlyLoadsOnce() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .value(makeResponse()))
        var changes = 0
        viewModel.onChange = { _ in changes += 1 }

        await viewModel.refreshIfNeeded()
        await viewModel.refreshIfNeeded()

        XCTAssertEqual(changes, 1)
        guard case .loaded = viewModel.state else {
            return XCTFail("Expected the loaded state, got \(viewModel.state)")
        }
    }

    func testAFailingPromiseShowsTheError() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .init(error: URLError(.notConnectedToInternet)))

        await viewModel.refresh()

        guard case let .error(message) = viewModel.state else {
            return XCTFail("Expected the error state, got \(viewModel.state)")
        }
        XCTAssertEqual(message, URLError(.notConnectedToInternet).localizedDescription)
        XCTAssertFalse(viewModel.isRefreshing)
    }

    /// The initial promise is used once; refreshing again asks the push server, which needs a push ID.
    func testRefreshingAgainWithoutAPushIDFails() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .value(makeResponse()))
        await viewModel.refresh()

        await viewModel.refresh()

        guard case .error = viewModel.state else {
            return XCTFail("Expected the error state, got \(viewModel.state)")
        }
    }

    func testNewPromiseWithoutAPushIDIsRejected() async {
        let promise = NotificationRateLimitViewModel.newPromise()
        let expectation = expectation(description: "rejected")

        promise.done { _ in
            XCTFail("Expected the promise to be rejected")
        }.catch { error in
            if case NotificationRateLimitViewModel.RateLimitError.noPushId = error {
                expectation.fulfill()
            } else {
                XCTFail("Unexpected error \(error)")
            }
        }

        await fulfillment(of: [expectation], timeout: 5)
    }

    func testTimerUpdatesTheCountdownUntilStopped() async throws {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .value(makeResponse()))
        await viewModel.refresh()

        viewModel.startTimer()
        viewModel.startTimer()
        viewModel.stopTimer()
        viewModel.stopTimer()

        let countdown = try XCTUnwrap(viewModel.resetsInText)
        XCTAssertFalse(countdown.isEmpty)
    }
}
