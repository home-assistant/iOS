import CallKit
@testable import HomeAssistant
@testable import Shared
import XCTest

final class IncomingCallControllerTests: XCTestCase {
    private var provider: FakeIncomingCallProvider!
    private var controller: IncomingCallController!
    private var sent: [(IncomingCallAction, String)]!
    private var opened: [IncomingCallRequest]!
    private var fallbacks: [IncomingCallRequest]!
    private var scheduled: [(TimeInterval, DispatchWorkItem)]!
    private var isAppActive: Bool!
    // Any provider will do as the delegate methods' argument; the controller only talks to `provider`.
    private let cxProvider = CXProvider(configuration: CXProviderConfiguration())

    override func setUp() {
        super.setUp()
        provider = FakeIncomingCallProvider()
        sent = []
        opened = []
        fallbacks = []
        scheduled = []
        isAppActive = false
        controller = IncomingCallController(
            provider: provider,
            sendAction: { [unowned self] action, request in sent.append((action, request.tag)) },
            open: { [unowned self] in opened.append($0) },
            postFallback: { [unowned self] in fallbacks.append($0) },
            isAppActive: { [unowned self] in isAppActive },
            schedule: { [unowned self] in scheduled.append(($0, $1)) }
        )
    }

    private func request(
        tag: String = "visio",
        caller: String? = "Papa",
        hasVideo: Bool = true
    ) -> IncomingCallRequest {
        .init(tag: tag, caller: caller, hasVideo: hasVideo, url: "/visio", timeout: 30, webhookID: nil)
    }

    /// Reports run their completion on the main queue.
    private func settle() {
        let done = expectation(description: "main queue")
        DispatchQueue.main.async { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    private func ring(_ request: IncomingCallRequest, mustReport: Bool = false) -> UUID? {
        controller.report(request, mustReport: mustReport)
        settle()
        return provider.reports.last?.uuid
    }

    private var sentActions: [IncomingCallAction] { sent.map(\.0) }

    // MARK: - Ringing

    func testReportsTheCall() throws {
        _ = ring(request(hasVideo: false))
        let update = try XCTUnwrap(provider.reports.first?.update)
        XCTAssertEqual(update.localizedCallerName, "Papa")
        XCTAssertEqual(update.remoteHandle?.type, .generic)
        XCTAssertFalse(update.hasVideo)
        XCTAssertFalse(update.supportsHolding)
        XCTAssertFalse(update.supportsDTMF)
        XCTAssertEqual(scheduled.map(\.0), [30])
        XCTAssertTrue(sent.isEmpty)
    }

    func testConfigurationKeepsCallsOutOfRecents() {
        let configuration = IncomingCallController.configuration
        XCTAssertFalse(configuration.includesCallsInRecents)
        XCTAssertTrue(configuration.supportsVideo)
        XCTAssertEqual(configuration.maximumCallGroups, 1)
        XCTAssertEqual(configuration.supportedHandleTypes, [.generic])
    }

    func testTimeoutIsMissed() throws {
        let uuid = try XCTUnwrap(ring(request()))
        scheduled[0].1.perform()
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .unanswered)])
        XCTAssertEqual(sentActions, [.missed])
    }

    func testSecondCallIsBusy() {
        _ = ring(request(tag: "first"))
        _ = ring(request(tag: "second"))
        XCTAssertEqual(provider.reports.count, 1)
        XCTAssertEqual(sent.map(\.1), ["second"])
        XCTAssertEqual(sentActions, [.busy])
    }

    func testSecondCallFromTheExtensionIsReportedThenEnded() {
        _ = ring(request(tag: "first"))
        let uuid = ring(request(tag: "second"), mustReport: true)
        XCTAssertEqual(provider.reports.count, 2)
        XCTAssertEqual(provider.ends, [.init(uuid: uuid!, reason: .unanswered)])
        XCTAssertEqual(sentActions, [.busy])
    }

    func testSameTagDoesNotRingTwice() {
        _ = ring(request())
        _ = ring(request())
        XCTAssertEqual(provider.reports.count, 1)
        XCTAssertTrue(sent.isEmpty)
    }

    func testFilteredCallIsMissedWithoutNotification() {
        provider.reportError = CXErrorCodeIncomingCallError(.filteredByDoNotDisturb)
        _ = ring(request())
        XCTAssertEqual(sentActions, [.missed])
        XCTAssertTrue(fallbacks.isEmpty)
    }

    func testFailedReportFallsBackToANotification() {
        provider.reportError = CXErrorCodeIncomingCallError(.unknown)
        _ = ring(request())
        XCTAssertEqual(fallbacks.map(\.tag), ["visio"])
        XCTAssertTrue(sent.isEmpty)
    }

    func testInvalidCallIsReportedAndEnded() {
        controller.reportInvalidCall()
        XCTAssertEqual(provider.reports.count, 1)
        XCTAssertEqual(provider.ends.map(\.reason), [.failed])
        XCTAssertTrue(sent.isEmpty)
    }

    // MARK: - User actions

    func testAnswerInTheBackgroundHandsOffOnceActive() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))

        XCTAssertEqual(sentActions, [.answer])
        XCTAssertEqual(opened.map(\.tag), ["visio"])
        XCTAssertTrue(scheduled[0].1.isCancelled, "the ring timeout is cancelled")
        XCTAssertEqual(scheduled.last?.0, IncomingCallController.handOffTimeout)
        XCTAssertTrue(provider.ends.isEmpty)

        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertEqual(sentActions, [.answer])
    }

    func testAnswerInTheForegroundHandsOffAtOnce() throws {
        isAppActive = true
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
    }

    func testAnsweredCallEndsAfterTheHandOffTimeout() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))
        scheduled.last?.1.perform()
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertEqual(sentActions, [.answer], "no missed event for an answered call")
    }

    func testDecline() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXEndCallAction(call: uuid))
        XCTAssertEqual(sentActions, [.decline])
        XCTAssertTrue(scheduled[0].1.isCancelled)
    }

    func testHangingUpAfterAnsweringSendsNothingMore() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))
        controller.provider(cxProvider, perform: CXEndCallAction(call: uuid))
        XCTAssertEqual(sentActions, [.answer])
    }

    func testUnknownCallActions() {
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: UUID()))
        controller.provider(cxProvider, perform: CXEndCallAction(call: UUID()))
        XCTAssertTrue(sent.isEmpty)
        XCTAssertTrue(opened.isEmpty)
    }

    // MARK: - Ended by Home Assistant

    func testClearNotificationEndsTheCall() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.end(tag: "other")
        XCTAssertTrue(provider.ends.isEmpty)

        NotificationCenter.default.post(name: IncomingCallPendingEnd.didRequestEnd, object: "visio")
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertTrue(sent.isEmpty, "Home Assistant ended it: no event back")
        XCTAssertTrue(scheduled[0].1.isCancelled)
    }

    func testResetForgetsCalls() throws {
        _ = try XCTUnwrap(ring(request()))
        controller.providerDidReset(cxProvider)
        XCTAssertTrue(scheduled[0].1.isCancelled)
        // A new call with the same tag rings again.
        _ = ring(request())
        XCTAssertEqual(provider.reports.count, 2)
    }
}
