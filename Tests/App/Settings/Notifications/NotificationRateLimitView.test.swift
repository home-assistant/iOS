import Foundation
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Shared state: the rate-limit request reads `Current.settingsStore.pushID` (preferences) and goes
/// through a process-wide HTTP stub.
@Suite(.sharedState)
@MainActor
struct NotificationRateLimitViewTests {
    private static let responseJSON = """
    {"target": "push-id", "rateLimits": {"attempts": 12, "successful": 10, "errors": 2, "total": 12,
     "maximum": 500, "remaining": 488, "resetsAt": "2026-10-31T00:00:00.000Z"}}
    """

    private static var response: RateLimitResponse {
        RateLimitResponse(
            target: "push-id",
            rateLimits: .init(
                attempts: 3,
                successful: 2,
                errors: 1,
                total: 3,
                maximum: 500,
                remaining: 497,
                resetsAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
    }

    @Test func loadsTheInitialResponse() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .value(Self.response))
        var changes: [RateLimitResponse] = []
        viewModel.onChange = { changes.append($0) }

        await viewModel.refreshIfNeeded()
        guard case let .loaded(response) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }
        #expect(response.rateLimits.attempts == 3)
        #expect(changes.count == 1)
        #expect(viewModel.resetsInText != nil)
        #expect(!viewModel.isRefreshing)

        // Already loaded: nothing to do.
        await viewModel.refreshIfNeeded()
        #expect(changes.count == 1)

        viewModel.startTimer()
        viewModel.stopTimer()
    }

    @Test func aFailedRequestShowsTheError() async {
        let viewModel = NotificationRateLimitViewModel(initialPromise: .init(error: URLError(.notConnectedToInternet)))
        await viewModel.refresh()
        guard case let .error(message) = viewModel.state else {
            Issue.record("expected error, got \(viewModel.state)")
            return
        }
        #expect(!message.isEmpty)
    }

    @Test func withoutAPushIDThereIsNothingToAsk() async {
        await withPushID(nil) {
            let viewModel = NotificationRateLimitViewModel(initialPromise: nil)
            await viewModel.refresh()
            guard case .error = viewModel.state else {
                Issue.record("expected error, got \(viewModel.state)")
                return
            }
        }
    }

    @Test func asksTheRateLimitServiceForThePushID() async {
        await withPushID("push-id") {
            var body: [String: Any]?
            let descriptor = stub(
                condition: { $0.url?.path == "/api/checkRateLimits" },
                response: { request in
                    if let data = request.ohhttpStubs_httpBody {
                        body = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                    }
                    return .init(data: Data(Self.responseJSON.utf8), statusCode: 200, headers: nil)
                }
            )
            defer { HTTPStubs.removeStub(descriptor) }

            let viewModel = NotificationRateLimitViewModel(initialPromise: nil)
            await viewModel.refresh()
            guard case let .loaded(response) = viewModel.state else {
                Issue.record("expected loaded, got \(viewModel.state)")
                return
            }
            #expect(response.rateLimits.maximum == 500)
            #expect(response.rateLimits.remaining == 488)
            #expect(body?["push_token"] as? String == "push-id")
        }
    }

    @Test func anUnreadableResponseIsAnError() async {
        await withPushID("push-id") {
            let descriptor = stub(
                condition: { $0.url?.path == "/api/checkRateLimits" },
                response: { _ in .init(data: Data("{}".utf8), statusCode: 200, headers: nil) }
            )
            defer { HTTPStubs.removeStub(descriptor) }

            do {
                _ = try await withCheckedThrowingContinuation { continuation in
                    NotificationRateLimitsAPI.rateLimits(pushID: "push-id")
                        .done { continuation.resume(returning: $0) }
                        .catch { continuation.resume(throwing: $0) }
                }
                Issue.record("expected a decoding error")
            } catch {
                #expect(error is DecodingError)
            }
        }
    }

    @Test func rendersLoadingLoadedAndError() async {
        let (pending, resolver) = Promise<RateLimitResponse>.pending()
        let loading = await SwiftUIScreenDriver.show(NotificationRateLimitView(initialPromise: pending))
        #expect(loading.rowCount(inSection: 0) == 1)
        // Settle the promise so the screen's load finishes instead of staying suspended on it.
        resolver.fulfill(Self.response)
        await #expect(loading.waitUntil { loading.rowCount(inSection: 0) == 5 })
        loading.close()

        var changes = 0
        let loaded = await SwiftUIScreenDriver.show(
            NotificationRateLimitView(initialPromise: .value(Self.response)) { _ in changes += 1 }
        )
        await #expect(loaded.waitUntil { loaded.rowCount(inSection: 0) == 5 })
        #expect(changes == 1)
        loaded.close()

        await withPushID(nil) {
            let failed = await SwiftUIScreenDriver.show(
                NotificationRateLimitView(initialPromise: .init(error: URLError(.timedOut)))
            )
            defer { failed.close() }
            // The message and a retry button, which asks again (and fails again without a push ID).
            await #expect(failed.waitUntil { failed.rowCount(inSection: 0) == 2 })
            await failed.tapRow(IndexPath(item: 1, section: 0))
            await #expect(failed.waitUntil { failed.rowCount(inSection: 0) == 2 })
        }
    }

    /// Pulling the list down asks again (here failing without a push ID); without an `onChange`
    /// handler the screen reports into its default no-op, and its countdown ticks every second.
    @Test func pullToRefreshAndTheCountdown() async throws {
        await withPushID(nil) {
            let driver = await SwiftUIScreenDriver
                .show(NotificationRateLimitView(initialPromise: .value(Self.response)))
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 5 })

            // Let the one-second countdown tick at least once.
            let tickAfter = Date().addingTimeInterval(1.2)
            while Date() < tickAfter {
                await driver.settle(1)
            }

            guard let refreshControl = driver.list?.refreshControl else {
                Issue.record("The list offers no pull to refresh")
                return
            }
            refreshControl.beginRefreshing()
            refreshControl.sendActions(for: .valueChanged)
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 2 })
        }
    }

    /// On the Mac there is no pull to refresh; a toolbar button asks again instead.
    @Test func theMacRefreshesFromTheToolbar() async {
        let previousCatalyst = Current.isCatalyst
        Current.isCatalyst = true
        defer { Current.isCatalyst = previousCatalyst }

        await withPushID(nil) {
            let driver = await SwiftUIScreenDriver
                .show(NotificationRateLimitView(initialPromise: .value(Self.response)))
            defer { driver.close() }
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 5 })
            #expect(driver.list?.refreshControl == nil)

            await driver.tapBarButton(0)
            await #expect(driver.waitUntil { driver.rowCount(inSection: 0) == 2 })
        }
    }

    private func withPushID(_ pushID: String?, _ body: () async -> Void) async {
        let previous = Current.settingsStore.pushID
        Current.settingsStore.pushID = pushID
        defer { Current.settingsStore.pushID = previous }
        await body()
    }
}
