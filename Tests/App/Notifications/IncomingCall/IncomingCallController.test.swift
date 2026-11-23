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
    private var date: Date!
    private var queuedEnds: [IncomingCallEndRequest]!
    // Any provider will do as the delegate methods' argument; the controller only talks to `provider`.
    private var cxProvider: CXProvider!

    override func setUp() {
        super.setUp()
        provider = FakeIncomingCallProvider()
        cxProvider = CXProvider(configuration: CXProviderConfiguration())
        sent = []
        opened = []
        fallbacks = []
        scheduled = []
        isAppActive = false
        date = Date(timeIntervalSince1970: 1_000_000)
        queuedEnds = []
        controller = IncomingCallController(
            provider: provider,
            sendAction: { [unowned self] action, request in sent.append((action, request.tag)) },
            open: { [unowned self] in opened.append($0) },
            postFallback: { [unowned self] in fallbacks.append($0) },
            isAppActive: { [unowned self] in isAppActive },
            schedule: { [unowned self] in scheduled.append(($0, $1)) },
            now: { [unowned self] in date },
            drainEndRequests: { [unowned self] in
                defer { queuedEnds = [] }
                return queuedEnds
            }
        )
    }

    override func tearDown() {
        // XCTest keeps test case instances alive: release the controller so its observers go with it.
        controller = nil
        provider = nil
        cxProvider = nil
        scheduled = nil
        super.tearDown()
    }

    private func request(
        tag: String = "visio",
        caller: String? = "Papa",
        hasVideo: Bool = true,
        webhookID: String? = "server"
    ) -> IncomingCallRequest {
        .init(
            tag: tag,
            caller: caller,
            hasVideo: hasVideo,
            url: "/visio",
            timeout: 30,
            webhookID: webhookID,
            actionData: ["tag": tag, "room": "salon"]
        )
    }

    private func end(_ tag: String = "visio", server: String? = "server") -> IncomingCallEndRequest {
        .init(tag: tag, webhookID: server, date: date)
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
        XCTAssertNotNil(configuration.iconTemplateImageData)
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
        // The failed call is forgotten: the next one rings.
        provider.reportError = nil
        _ = ring(request(tag: "next"))
        XCTAssertEqual(scheduled.count, 1)
    }

    func testInvalidCallIsReportedAndEnded() {
        controller.reportInvalidCall()
        XCTAssertEqual(provider.reports.count, 1)
        XCTAssertEqual(provider.ends.map(\.reason), [.failed])
        XCTAssertTrue(sent.isEmpty)
    }

    // MARK: - While CallKit is still reporting

    func testASecondDeliveryWhileReportingDoesNotRingTwice() {
        provider.defersReports = true
        controller.report(request())
        controller.report(request())
        controller.report(request(tag: "other"))
        XCTAssertEqual(provider.reports.count, 1)
        XCTAssertEqual(sentActions, [.busy])
    }

    func testAClearWhileReportingEndsTheCallOnceReported() throws {
        provider.defersReports = true
        controller.report(request())
        let uuid = try XCTUnwrap(provider.reports.first?.uuid)

        controller.end(end())
        provider.completeReports()
        settle()

        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertTrue(scheduled.isEmpty, "never rang, so no timeout")
        XCTAssertTrue(sent.isEmpty)
    }

    func testAResetWhileReportingEndsTheCallOnceReported() throws {
        provider.defersReports = true
        controller.report(request())
        let uuid = try XCTUnwrap(provider.reports.first?.uuid)

        controller.providerDidReset(cxProvider)
        provider.completeReports()
        settle()

        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertTrue(scheduled.isEmpty)
    }

    func testAClearQueuedBeforeTheReportEndsTheCall() throws {
        // Queued by the extension while iOS was still launching the app, before anything listened.
        queuedEnds = [end()]
        let uuid = try XCTUnwrap(ring(request()))
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertTrue(scheduled[0].1.isCancelled)
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

    func testAnsweringTwiceIsRefused() throws {
        let uuid = try XCTUnwrap(ring(request()))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))
        controller.provider(cxProvider, perform: CXAnswerCallAction(call: uuid))
        XCTAssertEqual(sentActions, [.answer])
        XCTAssertEqual(opened.count, 1)
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
        controller.end(end("other"))
        XCTAssertTrue(provider.ends.isEmpty)

        NotificationCenter.default.post(name: IncomingCallPendingEnd.didRequestEnd, object: end())
        XCTAssertEqual(provider.ends, [.init(uuid: uuid, reason: .remoteEnded)])
        XCTAssertTrue(sent.isEmpty, "Home Assistant ended it: no event back")
        XCTAssertTrue(scheduled[0].1.isCancelled)
    }

    func testAClearFromAnotherServerDoesNotEndTheCall() throws {
        _ = try XCTUnwrap(ring(request()))
        controller.end(end(server: "another-server"))
        XCTAssertTrue(provider.ends.isEmpty)
    }

    func testAnOlderClearDoesNotEndANewerCallWithTheSameTag() throws {
        let olderClear = end()
        date += 5
        _ = try XCTUnwrap(ring(request()))
        controller.end(olderClear)
        XCTAssertTrue(provider.ends.isEmpty)
    }

    func testResetForgetsCalls() throws {
        _ = try XCTUnwrap(ring(request()))
        controller.providerDidReset(cxProvider)
        XCTAssertTrue(scheduled[0].1.isCancelled)
        // A new call with the same tag rings again.
        _ = ring(request())
        XCTAssertEqual(provider.reports.count, 2)
    }

    // MARK: - Default dependencies

    func testActionInfoSendsTheCallsActionData() {
        let info = IncomingCallController.actionInfo(.answer, for: request())
        XCTAssertEqual(info.identifier, "CALL_ANSWER")
        XCTAssertNil(info.category)
        XCTAssertEqual(info.actionData as? NSDictionary, ["tag": "visio", "room": "salon"] as NSDictionary)
    }

    func testFallbackNotification() throws {
        let fallback = IncomingCallController.fallbackRequest(for: request())
        XCTAssertEqual(fallback.identifier, "visio", "identified by the tag, so clear_notification removes it")
        XCTAssertNil(fallback.trigger)

        let content = fallback.content
        XCTAssertEqual(content.title, "Papa")
        XCTAssertEqual(content.body, L10n.IncomingCall.video)
        XCTAssertEqual(content.interruptionLevel, .timeSensitive)
        XCTAssertEqual(content.categoryIdentifier, "DYNAMIC")
        XCTAssertNotNil(content.sound)
        XCTAssertEqual(content.userInfo["webhook_id"] as? String, "server")

        let actions = try XCTUnwrap(content.userInfo["actions"] as? [[String: Any]])
        XCTAssertEqual(actions.compactMap { $0["action"] as? String }, ["CALL_ANSWER", "CALL_DECLINE"])
        XCTAssertTrue(actions.allSatisfy { $0["uri"] == nil }, "the app opens the validated page itself")

        let homeassistant = try XCTUnwrap(content.userInfo["homeassistant"] as? [String: Any])
        XCTAssertEqual(homeassistant[IncomingCallRequest.notificationMarker] as? Bool, true)
        XCTAssertEqual(homeassistant["url"] as? String, "/visio")
        XCTAssertEqual(homeassistant["room"] as? String, "salon")
        XCTAssertTrue(IncomingCallRequest.isIncomingCallNotification(userInfo: content.userInfo))
        XCTAssertFalse(IncomingCallRequest.isIncomingCall(userInfo: content.userInfo), "never rings again")
    }

    func testFallbackNotificationForAnAudioCall() {
        let content = IncomingCallController.fallbackRequest(for: request(hasVideo: false)).content
        XCTAssertEqual(content.body, L10n.IncomingCall.audio)
    }
}
