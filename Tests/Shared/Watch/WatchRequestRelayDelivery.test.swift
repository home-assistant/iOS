import Foundation
@testable import Shared
import Testing
import WatchConnectivity

/// Drives the WatchConnectivity leg of the relay through a session the test answers itself, so the
/// three ways a wait can end — the phone's reply, a delivery error, and a caller that gave up —
/// each settle it exactly once and none of them leaves the caller suspended.
struct WatchRequestRelayDeliveryTests {
    private func payload() -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "123",
            url: URL(string: "https://ha.example.com/api/states")!,
            method: "GET",
            headers: [:],
            body: nil,
            timeout: 8
        )
    }

    private func envelope(for response: WatchHTTPResponsePayload) -> [String: Any] {
        HAWatchConnectivity.ImmediateMessage(
            identifier: InteractiveImmediateResponses.httpRequestResponse.rawValue,
            content: response.content
        ).jsonRepresentation()
    }

    @Test func putsTheWatchsRequestOnTheLinkAndReturnsWhatThePhoneAnswers() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.firstSend()
        let sent = try #require(HAWatchConnectivity.ImmediateMessage(content: send.message))
        #expect(sent.identifier == InteractiveImmediateMessages.httpRequest.rawValue)
        #expect(WatchHTTPRequestPayload(content: sent.content)?.url == payload().url)

        send.replyHandler?(envelope(for: .response(statusCode: 200, headers: [:], body: Data("ok".utf8))))

        let answer = await relayed.value
        guard case let .response(statusCode, _, body) = answer else {
            Issue.record("expected the phone's response")
            return
        }
        #expect(statusCode == 200)
        #expect(body == Data("ok".utf8))
    }

    /// The message never got there, so nothing was performed and the watch is free to try itself.
    @Test func reportsNothingWhenTheLinkRejectsTheMessage() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.firstSend()
        send.errorHandler?(HAWatchConnectivity.ConnectivityError.notReachable)

        let answer = await relayed.value
        #expect(answer == nil)
    }

    /// A caller that gives up — the magic-item watchdog, a cancelled refresh — must not wait out the
    /// phone's budget. The reply that lands afterwards is dropped rather than resuming a wait nobody
    /// is on any more, which would trap.
    @Test func settlesImmediatelyWhenTheCallerGivesUp() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 30, over: manager) }

        let send = try await session.firstSend()
        relayed.cancel()

        let answer = await relayed.value
        #expect(answer == nil)

        send.replyHandler?(envelope(for: .response(statusCode: 200, headers: [:], body: Data())))
    }

    /// No paired counterpart at all: the send fails before it reaches the link, which is the same
    /// answer as any other undelivered message.
    @Test func reportsNothingWhenThereIsNoSession() async {
        let answer = await WatchRequestRelay.deliver(
            payload(),
            budget: 10,
            over: WatchConnectivityManager(session: nil)
        )

        #expect(answer == nil)
    }
}

/// A `WCSession` stand-in that records outgoing interactive sends instead of delivering them, so
/// the test holds both handlers and decides which one fires.
private final class RelayLinkSession: WCSessionProtocol, @unchecked Sendable {
    typealias Send = (
        message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )

    private let lock = NSLock()
    private var sends: [Send] = []

    var delegateProxy: WCSessionDelegate?
    var activationStateProxy: WCSessionActivationState = .activated
    var isReachableProxy = true
    var hasContentPendingProxy = false
    var applicationContextProxy: [String: Any] = [:]
    var receivedApplicationContextProxy: [String: Any] = [:]
    var outstandingUserInfoTransfersProxy: [[String: Any]] = []

    func activateProxy() {}

    func sendMessageProxy(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        lock.lock()
        sends.append((message, replyHandler, errorHandler))
        lock.unlock()
    }

    func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws {}

    @discardableResult func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        RelayLinkTransferHandle()
    }

    @discardableResult func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle {
        RelayLinkTransferHandle()
    }

    #if os(iOS)
    var isPairedProxy = true
    var isWatchAppInstalledProxy = true
    var isComplicationEnabledProxy = false
    var remainingComplicationUserInfoTransfersProxy = 50
    var watchDirectoryURLProxy: URL?

    @discardableResult func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        RelayLinkTransferHandle()
    }
    #endif

    /// The request the relay put on the link, once it is there — the relay sends from its own task,
    /// so the test has to wait for it rather than assume it already happened.
    func firstSend(within attempts: Int = 200) async throws -> Send {
        for _ in 0 ..< attempts {
            lock.lock()
            let first = sends.first
            lock.unlock()
            if let first { return first }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw RelayLinkNeverSent()
    }
}

private struct RelayLinkNeverSent: Error {}

private final class RelayLinkTransferHandle: WCTransferHandle {}
