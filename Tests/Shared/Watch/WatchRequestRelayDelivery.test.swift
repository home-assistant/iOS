import Foundation
@testable import Shared
import Testing
import WatchConnectivity

/// Drives the WatchConnectivity leg of the relay through a session the test answers itself, so the
/// ways a wait can end — the phone's reply, a delivery error, a reply that never comes, and a
/// caller that gave up — each settle it exactly once, tell the relay whether the phone got the
/// request, and none of them leaves the caller suspended.
struct WatchRequestRelayDeliveryTests {
    private func payload(url: String = "https://ha.example.com/api/states") -> WatchHTTPRequestPayload {
        WatchHTTPRequestPayload(
            serverId: "123",
            url: URL(string: url)!,
            method: "GET",
            headers: [:],
            body: nil,
            timeout: 8
        )
    }

    private let ok = WatchHTTPResponsePayload.response(statusCode: 200, headers: [:], body: Data("ok".utf8))

    private func envelope(for response: WatchHTTPResponsePayload) -> [String: Any] {
        HAWatchConnectivity.ImmediateMessage(
            identifier: InteractiveImmediateResponses.httpRequestResponse.rawValue,
            content: response.content
        ).jsonRepresentation()
    }

    private func filler() -> HAWatchConnectivity.InteractiveImmediateMessage {
        HAWatchConnectivity.InteractiveImmediateMessage(identifier: "filler", reply: { _ in })
    }

    private func occupyEverySlot(of manager: WatchConnectivityManager) {
        for _ in 0 ..< WatchConnectivityManager.maxConcurrentInteractiveSends {
            manager.send(filler())
        }
    }

    private func waitForPendingSends(_ count: Int, on manager: WatchConnectivityManager) async throws {
        for _ in 0 ..< 200 {
            manager.sendQueueLock.lock()
            let pending = manager.pendingInteractiveSends.count
            manager.sendQueueLock.unlock()
            if pending == count { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw RelayLinkNeverSent()
    }

    private func relayedURL(of send: RelayLinkSession.Send) -> URL? {
        guard let sent = HAWatchConnectivity.ImmediateMessage(content: send.message) else { return nil }
        return WatchHTTPRequestPayload(content: sent.content)?.url
    }

    @Test func putsTheWatchsRequestOnTheLinkAndReturnsWhatThePhoneAnswers() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.send(at: 0)
        let sent = try #require(HAWatchConnectivity.ImmediateMessage(content: send.message))
        #expect(sent.identifier == InteractiveImmediateMessages.httpRequest.rawValue)
        #expect(WatchHTTPRequestPayload(content: sent.content)?.url == payload().url)

        send.replyHandler?(envelope(for: ok))

        let answer = await relayed.value
        #expect(answer == .answered(ok))
    }

    /// The message never got there, so nothing was performed and the watch is free to try itself.
    @Test func reportsNotSentWhenTheLinkRejectsTheMessage() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.send(at: 0)
        send.errorHandler?(HAWatchConnectivity.ConnectivityError.notReachable)

        let answer = await relayed.value
        #expect(answer == .notSent)
    }

    @Test func reportsUnansweredWhenTheReplyNeverComes() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 0.1, over: manager) }

        _ = try await session.send(at: 0)

        let answer = await relayed.value
        #expect(answer == .unanswered)
    }

    @Test func reportsUnansweredWhenTheLinkSaysTheReplyTimedOut() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.send(at: 0)
        send.errorHandler?(NSError(domain: WCErrorDomain, code: WCError.Code.messageReplyTimedOut.rawValue))

        let answer = await relayed.value
        #expect(answer == .unanswered)
    }

    @Test func reportsUnansweredWhenThePhonesReplyCannotBeDecoded() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 10, over: manager) }

        let send = try await session.send(at: 0)
        send.replyHandler?(HAWatchConnectivity.ImmediateMessage(
            identifier: InteractiveImmediateResponses.httpRequestResponse.rawValue,
            content: ["unexpected": true]
        ).jsonRepresentation())

        let answer = await relayed.value
        #expect(answer == .unanswered)
    }

    /// A caller that gives up — the magic-item watchdog, a cancelled refresh — must not wait out the
    /// phone's budget. The reply that lands afterwards is dropped rather than resuming a wait nobody
    /// is on any more, which would trap.
    @Test func settlesImmediatelyWhenTheCallerGivesUp() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 30, over: manager) }

        let send = try await session.send(at: 0)
        relayed.cancel()

        let answer = await relayed.value
        #expect(answer == .notSent)

        send.replyHandler?(envelope(for: ok))
    }

    @Test func withdrawsAQueuedSendWhenTheCallerGivesUp() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        occupyEverySlot(of: manager)
        let relayed = Task { await WatchRequestRelay.deliver(payload(), budget: 30, over: manager) }
        try await waitForPendingSends(1, on: manager)

        relayed.cancel()
        let answer = await relayed.value
        #expect(answer == .notSent)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        try await session.send(at: 0).replyHandler?(reply)
        try await session.send(at: 1).replyHandler?(reply)
        try await Task.sleep(nanoseconds: 50_000_000)
        #expect(session.sendCount == WatchConnectivityManager.maxConcurrentInteractiveSends)
    }

    @Test func aUserActionOvertakesQueuedBackgroundRelays() async throws {
        let session = RelayLinkSession()
        let manager = WatchConnectivityManager(session: session)
        occupyEverySlot(of: manager)
        let refresh = Task {
            await WatchRequestRelay.deliver(
                payload(url: "https://ha.example.com/api/states/sensor.a"),
                budget: 30,
                priority: .background,
                over: manager
            )
        }
        try await waitForPendingSends(1, on: manager)
        let tap = Task {
            await WatchRequestRelay.deliver(
                payload(url: "https://ha.example.com/api/services/script/turn_on"),
                budget: 30,
                priority: .userAction,
                over: manager
            )
        }
        try await waitForPendingSends(2, on: manager)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        try await session.send(at: 0).replyHandler?(reply)
        let next = try await session.send(at: 2)
        #expect(relayedURL(of: next)?.path == "/api/services/script/turn_on")

        next.replyHandler?(envelope(for: ok))
        try await session.send(at: 1).replyHandler?(reply)
        try await session.send(at: 3).replyHandler?(envelope(for: ok))
        let tapped = await tap.value
        #expect(tapped == .answered(ok))
        let refreshed = await refresh.value
        #expect(refreshed == .answered(ok))
    }

    /// No paired counterpart at all: the send fails before it reaches the link, which is the same
    /// answer as any other undelivered message.
    @Test func reportsNotSentWhenThereIsNoSession() async {
        let answer = await WatchRequestRelay.deliver(
            payload(),
            budget: 10,
            over: WatchConnectivityManager(session: nil)
        )

        #expect(answer == .notSent)
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

    var sendCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return sends.count
    }

    /// The request at `index` on the link, once it is there — the relay sends from its own task,
    /// so the test has to wait for it rather than assume it already happened.
    func send(at index: Int, within attempts: Int = 200) async throws -> Send {
        for _ in 0 ..< attempts {
            lock.lock()
            let send: Send? = sends.indices.contains(index) ? sends[index] : nil
            lock.unlock()
            if let send { return send }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw RelayLinkNeverSent()
    }
}

private struct RelayLinkNeverSent: Error {}

private final class RelayLinkTransferHandle: WCTransferHandle {}
