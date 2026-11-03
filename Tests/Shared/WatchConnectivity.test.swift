import Foundation
@testable import Shared
import SharedTesting
import Testing
import WatchConnectivity

private final class FakeTransferHandle: WCTransferHandle {}

private final class FakeWCSession: WCSessionProtocol {
    var delegateProxy: WCSessionDelegate?
    var activationStateProxy: WCSessionActivationState = .activated
    var isReachableProxy = true
    var hasContentPendingProxy = false
    var applicationContextProxy: [String: Any] = [:]
    var receivedApplicationContextProxy: [String: Any] = [:]
    var outstandingUserInfoTransfersProxy: [[String: Any]] = []

    var didActivate = false
    var sentMessages: [(
        message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    )] = []
    var updatedContexts: [[String: Any]] = []
    var transferredUserInfos: [[String: Any]] = []
    var transferredFiles: [(url: URL, metadata: [String: Any]?)] = []
    var updateContextError: Error?
    var lastFileHandle: FakeTransferHandle?

    func activateProxy() { didActivate = true }

    func sendMessageProxy(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {
        sentMessages.append((message, replyHandler, errorHandler))
    }

    func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws {
        if let updateContextError { throw updateContextError }
        updatedContexts.append(applicationContext)
        applicationContextProxy = applicationContext
    }

    @discardableResult func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        transferredUserInfos.append(userInfo)
        return FakeTransferHandle()
    }

    @discardableResult func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle {
        transferredFiles.append((file, metadata))
        let handle = FakeTransferHandle()
        lastFileHandle = handle
        return handle
    }

    #if os(iOS)
    var isPairedProxy = true
    var isWatchAppInstalledProxy = true
    var isComplicationEnabledProxy = false
    var remainingComplicationUserInfoTransfersProxy = 50
    var watchDirectoryURLProxy: URL?
    var transferredComplicationUserInfos: [[String: Any]] = []
    var lastComplicationHandle: FakeTransferHandle?

    @discardableResult func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        transferredComplicationUserInfos.append(userInfo)
        let handle = FakeTransferHandle()
        lastComplicationHandle = handle
        return handle
    }
    #endif
}

private final class ValueBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T?
    private var onMainStorage = false
    private var countStorage = 0

    func set(_ value: T, onMain: Bool = Thread.isMainThread) {
        lock.lock()
        stored = value
        onMainStorage = onMain
        countStorage += 1
        lock.unlock()
    }

    var value: T? {
        lock.lock(); defer { lock.unlock() }
        return stored
    }

    var wasOnMain: Bool {
        lock.lock(); defer { lock.unlock() }
        return onMainStorage
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return countStorage
    }
}

@Suite(.sharedState)
struct WatchConnectivityEnvelope_test {
    @Test func immediateMessageRoundTripPreservesDataPayload() throws {
        let payload: [String: Any] = ["config": Data([0x01, 0x02, 0x03]), "count": 4]
        let message = HAWatchConnectivity.ImmediateMessage(identifier: "watchConfig", content: payload)
        let envelope = message.jsonRepresentation()

        #expect(envelope["identifier"] as? String == "watchConfig")
        let decoded = try #require(HAWatchConnectivity.ImmediateMessage(content: envelope))
        #expect(decoded.identifier == "watchConfig")
        #expect(decoded.content["config"] as? Data == Data([0x01, 0x02, 0x03]))
        #expect(decoded.content["count"] as? Int == 4)
    }

    @Test func decodeRejectsEnvelopeMissingKeys() {
        #expect(HAWatchConnectivity.ImmediateMessage(content: ["identifier": "x"]) == nil)
        #expect(HAWatchConnectivity.ImmediateMessage(content: ["content": [String: Any]()]) == nil)
        #expect(HAWatchConnectivity.GuaranteedMessage(content: [:]) == nil)
    }

    @Test func guaranteedMessageRoundTrip() throws {
        let message = HAWatchConnectivity.GuaranteedMessage(identifier: "sync")
        let decoded = try #require(HAWatchConnectivity.GuaranteedMessage(content: message.jsonRepresentation()))
        #expect(decoded.identifier == "sync")
    }

    @Test func complicationInfoEnvelope() throws {
        let info = HAWatchConnectivity.ComplicationInfo(content: ["a": 1])
        let envelope = info.jsonRepresentation()
        #expect(envelope["__complication_info__"] != nil)
        let decoded = try #require(HAWatchConnectivity.ComplicationInfo(jsonDictionary: envelope))
        #expect(decoded.content["a"] as? Int == 1)
        #expect(HAWatchConnectivity.ComplicationInfo(jsonDictionary: ["nope": 1]) == nil)
    }

    @Test func blobDataRoundTrip() throws {
        let blob = HAWatchConnectivity.Blob(identifier: "audio", content: Data([0xAA, 0xBB]))
        let data = try #require(blob.dataRepresentation())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = try #require(HAWatchConnectivity.Blob.decode(fileURL: url, metadata: ["k": "v"]))
        #expect(decoded.identifier == "audio")
        #expect(decoded.content == Data([0xAA, 0xBB]))
        #expect(decoded.metadata?["k"] as? String == "v")
    }
}

struct WatchConnectivityReply_test {
    @Test func replyFiresExactlyOnce() {
        var replyEnvelopes: [[String: Any]] = []
        let message = HAWatchConnectivity.InteractiveImmediateMessage(
            content: HAWatchConnectivity.InteractiveImmediateMessage(
                identifier: "ping",
                content: [:],
                reply: { _ in }
            ).jsonRepresentation(),
            wcReplyHandler: { replyEnvelopes.append($0) }
        )
        let received = try? #require(message)
        received?.reply(HAWatchConnectivity.ImmediateMessage(identifier: "pong", content: ["ok": true]))
        received?.reply(HAWatchConnectivity.ImmediateMessage(identifier: "pong", content: ["ok": true]))

        #expect(replyEnvelopes.count == 1)
        #expect(replyEnvelopes.first?["identifier"] as? String == "pong")
    }
}

struct WatchConnectivitySend_test {
    @Test func interactiveSendNotReachableSurfacesError() {
        let fake = FakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)

        var error: Error?
        manager.send(
            HAWatchConnectivity.InteractiveImmediateMessage(identifier: "watchConfig", reply: { _ in }),
            errorHandler: { error = $0 }
        )
        #expect(fake.sentMessages.isEmpty)
        #expect(error as? HAWatchConnectivity.ConnectivityError == .notReachable)
    }

    @Test func interactiveSendAndReplyRoundTrip() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        var receivedReply: HAWatchConnectivity.ImmediateMessage?
        manager.send(HAWatchConnectivity.InteractiveImmediateMessage(
            identifier: "watchConfig",
            content: ["x": 1],
            reply: { receivedReply = $0 }
        ))
        #expect(fake.sentMessages.count == 1)
        #expect(fake.sentMessages[0].message["identifier"] as? String == "watchConfig")

        let responseEnvelope = HAWatchConnectivity.ImmediateMessage(
            identifier: "watchConfigResponse",
            content: ["ok": true]
        ).jsonRepresentation()
        fake.sentMessages[0].replyHandler?(responseEnvelope)
        #expect(receivedReply?.identifier == "watchConfigResponse")
        #expect(receivedReply?.content["ok"] as? Bool == true)
    }

    @Test func interactiveSendTimesOutWhenNoReply() async throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        var error: Error?
        manager.send(
            HAWatchConnectivity.InteractiveImmediateMessage(identifier: "watchConfig", reply: { _ in }),
            timeout: 0.1,
            errorHandler: { error = $0 }
        )
        #expect(fake.sentMessages.count == 1)
        let reached1 = await waitUntil { error != nil }
        #expect(reached1)
        #expect(error as? HAWatchConnectivity.ConnectivityError == .replyTimedOut)
    }

    @Test func interactiveReplyCancelsTimeout() async throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        var receivedReply: HAWatchConnectivity.ImmediateMessage?
        var error: Error?
        manager.send(
            HAWatchConnectivity.InteractiveImmediateMessage(identifier: "watchConfig", reply: { receivedReply = $0 }),
            timeout: 0.1,
            errorHandler: { error = $0 }
        )
        fake.sentMessages[0].replyHandler?(
            HAWatchConnectivity.ImmediateMessage(identifier: "watchConfigResponse").jsonRepresentation()
        )
        let reached2 = await waitUntil { receivedReply != nil }
        #expect(reached2)
        #expect(receivedReply?.identifier == "watchConfigResponse")
        // Past the timeout, which must not fire: a short wait only because this checks for nothing.
        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(error == nil)
    }

    @Test func guaranteedSendUsesTransferUserInfoWithoutReachability() {
        let fake = FakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)

        manager.send(HAWatchConnectivity.GuaranteedMessage(identifier: "sync"))
        #expect(fake.transferredUserInfos.count == 1)
        #expect(fake.transferredUserInfos[0]["identifier"] as? String == "sync")
        #expect(fake.sentMessages.isEmpty)
    }

    @Test func syncUpdatesContextWithoutReachabilityAndBridgesThrow() throws {
        let fake = FakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)

        try manager.sync(HAWatchConnectivity.Context(content: ["ssid": "home"]))
        #expect(fake.updatedContexts.count == 1)
        #expect(fake.updatedContexts[0]["ssid"] as? String == "home")

        fake.updateContextError = HAWatchConnectivity.ConnectivityError.payloadTooLarge
        do {
            try manager.sync(HAWatchConnectivity.Context(content: [:]))
            Issue.record("expected sync to throw")
        } catch {
            guard case HAWatchConnectivity.ConnectivityError.deliveryFailed = error else {
                Issue.record("expected .deliveryFailed, got \(error)")
                return
            }
            let nsError = error as NSError
            #expect(nsError.domain == "HAWatchConnectivity")
            #expect(nsError.userInfo[NSUnderlyingErrorKey] != nil)
        }
    }

    @Test func unsupportedSessionNoOps() {
        let manager = WatchConnectivityManager(session: nil)
        #expect(manager.isSupported == false)
        #expect(manager.currentReachability == .notReachable)
        #expect(manager.hasPendingDataToBeReceived == false)

        var error: Error?
        manager.send(
            HAWatchConnectivity.ImmediateMessage(identifier: "wakeup"),
            errorHandler: { error = $0 }
        )
        #expect(error as? HAWatchConnectivity.ConnectivityError == .sessionNotSupported)

        #expect(throws: HAWatchConnectivity.ConnectivityError.sessionNotSupported) {
            try manager.sync(HAWatchConnectivity.Context())
        }
    }

    @Test func oneWayImmediateSendUsesNilReplyHandlerWhenReachable() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup", content: ["a": 1]))
        #expect(fake.sentMessages.count == 1)
        #expect(fake.sentMessages[0].message["identifier"] as? String == "wakeup")
        #expect(fake.sentMessages[0].replyHandler == nil)
    }

    @Test func notActivatedSessionSurfacesNotActivatedOnEveryPath() throws {
        let fake = FakeWCSession()
        fake.activationStateProxy = .notActivated
        let manager = WatchConnectivityManager(session: fake)

        var immediateError: Error?
        manager.send(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup"), errorHandler: { immediateError = $0 })
        #expect(immediateError as? HAWatchConnectivity.ConnectivityError == .sessionNotActivated)

        var interactiveError: Error?
        manager.send(
            HAWatchConnectivity.InteractiveImmediateMessage(identifier: "watchConfig", reply: { _ in }),
            errorHandler: { interactiveError = $0 }
        )
        #expect(interactiveError as? HAWatchConnectivity.ConnectivityError == .sessionNotActivated)
        #expect(fake.sentMessages.isEmpty)

        manager.send(HAWatchConnectivity.GuaranteedMessage(identifier: "sync"))
        #expect(fake.transferredUserInfos.isEmpty)

        #expect(throws: HAWatchConnectivity.ConnectivityError.sessionNotActivated) {
            try manager.sync(HAWatchConnectivity.Context())
        }

        var blobResult: Result<Void, Error>?
        manager.transfer(HAWatchConnectivity.Blob(identifier: "b", content: Data()), completion: { blobResult = $0 })
        if case let .failure(error) = blobResult {
            #expect(error as? HAWatchConnectivity.ConnectivityError == .sessionNotActivated)
        } else {
            Issue.record("expected blob transfer to fail when not activated")
        }
    }

    @Test func blobTransferStagesFileAndResolvesCompletion() throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        var result: Result<Void, Error>?
        manager.transfer(
            HAWatchConnectivity.Blob(identifier: "audio", content: Data([0x01])),
            completion: { result = $0 }
        )
        #expect(fake.transferredFiles.count == 1)
        let handle = try #require(fake.lastFileHandle)
        manager.resolveFileTransfer(handle, error: nil)
        if case .success = result { } else { Issue.record("expected success") }
    }
}

/// Polls for work the manager hands to the main queue, which a busy runner can take far longer
/// than a fixed sleep to get to.
private func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else { return false }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    return true
}

struct WatchConnectivityReceive_test {
    @Test func interactiveVsImmediateRouting() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let interactiveBox = ValueBox<HAWatchConnectivity.InteractiveImmediateMessage>()
        let immediateBox = ValueBox<HAWatchConnectivity.ImmediateMessage>()
        manager.interactiveImmediateMessage.observe { interactiveBox.set($0) }
        manager.immediateMessage.observe { immediateBox.set($0) }

        let envelope = HAWatchConnectivity.ImmediateMessage(identifier: "watchConfig").jsonRepresentation()
        manager.receiveMessage(envelope, replyHandler: { _ in })
        manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())

        let arrived = await waitUntil { interactiveBox.value != nil && immediateBox.value != nil }

        #expect(arrived)
        #expect(interactiveBox.value?.identifier == "watchConfig")
        #expect(immediateBox.value?.identifier == "wakeup")
        #expect(interactiveBox.count == 1)
    }

    @Test func userInfoRoutesComplicationVsGuaranteed() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let complicationBox = ValueBox<HAWatchConnectivity.ComplicationInfo>()
        let guaranteedBox = ValueBox<HAWatchConnectivity.GuaranteedMessage>()
        manager.complicationInfo.observe { complicationBox.set($0) }
        manager.guaranteedMessage.observe { guaranteedBox.set($0) }

        manager.receiveUserInfo(HAWatchConnectivity.ComplicationInfo(content: [:]).jsonRepresentation())
        manager.receiveUserInfo(HAWatchConnectivity.GuaranteedMessage(identifier: "sync").jsonRepresentation())

        let arrived = await waitUntil { complicationBox.count > 0 && guaranteedBox.value != nil }

        #expect(arrived)
        #expect(complicationBox.count == 1)
        #expect(guaranteedBox.value?.identifier == "sync")
    }

    @Test func handlersRunOnMainQueue() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let box = ValueBox<HAWatchConnectivity.ImmediateMessage>()
        manager.immediateMessage.observe { box.set($0) }

        DispatchQueue.global().async {
            manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())
        }
        let arrived = await waitUntil { box.value != nil }
        #expect(arrived)
        #expect(box.value?.identifier == "wakeup")
        #expect(box.wasOnMain == true)
    }

    @Test func observeAndUnobserveStopsDelivery() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let box = ValueBox<HAWatchConnectivity.ImmediateMessage>()
        let token = manager.immediateMessage.observe { box.set($0) }
        manager.immediateMessage.unobserve(token)

        manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(box.count == 0)
    }

    @Test func storeIdiomDeliversAndCanBeRemoved() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let box = ValueBox<HAWatchConnectivity.ImmediateMessage>()
        let observation = HAWatchConnectivity.Observation()
        manager.immediateMessage.store[observation] = { box.set($0) }

        manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())
        let arrived = await waitUntil { box.value != nil }
        #expect(arrived)
        #expect(box.value?.identifier == "wakeup")
        #expect(box.wasOnMain == true)

        manager.immediateMessage.store[observation] = nil
        manager.receiveMessage(HAWatchConnectivity.ImmediateMessage(identifier: "wakeup").jsonRepresentation())
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(box.count == 1)
    }

    @Test func interactiveReceiveRepliesEvenOnDecodeFailure() async throws {
        let manager = WatchConnectivityManager(session: FakeWCSession())
        let interactiveBox = ValueBox<HAWatchConnectivity.InteractiveImmediateMessage>()
        manager.interactiveImmediateMessage.observe { interactiveBox.set($0) }

        let replied = ValueBox<Bool>()
        manager.receiveMessage(["identifier": "x"], replyHandler: { _ in replied.set(true) })
        let arrived = await waitUntil { replied.value == true }
        #expect(arrived)
        #expect(interactiveBox.count == 0)
    }

    /// `refreshConnectivityState()` re-reads the live `isReachable` and re-broadcasts it. This is what
    /// lets the watch recover a stale "unreachable" on foreground (watchOS doesn't reliably emit
    /// `sessionReachabilityDidChange` across a suspend→resume) without an app restart.
    @Test func refreshConnectivityStateRebroadcastsLiveReachability() async throws {
        let fake = FakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)
        let box = ValueBox<HAWatchConnectivity.Reachability>()
        manager.reachability.observe { box.set($0) }

        // The value flipped to reachable while suspended, but no delegate callback fired.
        fake.isReachableProxy = true
        manager.refreshConnectivityState()

        let arrived = await waitUntil { box.value == .immediatelyReachable }

        #expect(arrived)
        #expect(box.value == .immediatelyReachable)
        #expect(manager.currentReachability == .immediatelyReachable)
    }

    /// Senders gate capability-dependent messages on this, and an unrecognised identifier is never
    /// replied to — so a version that hasn't arrived yet has to read as "too old", not as absent.
    @Test func counterpartProtocolVersionIsUnknownUntilSomethingArrives() {
        let manager = WatchConnectivityManager(session: FakeWCSession())

        #expect(manager.counterpartProtocolVersion == nil)
    }

    @Test func counterpartProtocolVersionIsLearnedFromAnyInboundMessage() {
        let manager = WatchConnectivityManager(session: FakeWCSession())

        manager.receiveMessage(["identifier": "ping", "content": [:], "version": 2])

        #expect(manager.counterpartProtocolVersion == 2)
    }

    /// A message from a build that predates versioning can arrive after a versioned one — a queued
    /// `transferUserInfo`, say — and must not walk the learned capability back.
    @Test func counterpartProtocolVersionNeverDecreases() {
        let manager = WatchConnectivityManager(session: FakeWCSession())

        manager.receiveMessage(["identifier": "ping", "content": [:], "version": 2])
        manager.receiveMessage(["identifier": "ping", "content": [:]])
        manager.receiveMessage(["identifier": "ping", "content": [:], "version": 1])

        #expect(manager.counterpartProtocolVersion == 2)
    }
}

#if os(iOS)
struct WatchConnectivityWatchState_test {
    @Test func watchStateDerivation() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        fake.isPairedProxy = false
        #expect(manager.currentWatchState == .notPaired)

        fake.isPairedProxy = true
        fake.isWatchAppInstalledProxy = false
        #expect(manager.currentWatchState == .paired(.notInstalled))

        fake.isWatchAppInstalledProxy = true
        fake.isComplicationEnabledProxy = false
        #expect(manager.currentWatchState == .paired(.installed(.notEnabled, nil)))

        fake.isComplicationEnabledProxy = true
        fake.remainingComplicationUserInfoTransfersProxy = 7
        #expect(manager.currentWatchState == .paired(.installed(.enabled(numberOfUpdatesAvailableToday: 7), nil)))
    }

    @Test func complicationTransferResolvesWithRemainingBudget() throws {
        let fake = FakeWCSession()
        fake.remainingComplicationUserInfoTransfersProxy = 12
        let manager = WatchConnectivityManager(session: fake)

        var result: Result<Int, Error>?
        manager.transfer(HAWatchConnectivity.ComplicationInfo(content: [:]), completion: { result = $0 })
        #expect(fake.transferredComplicationUserInfos.count == 1)
        let handle = try #require(fake.lastComplicationHandle)
        manager.resolveComplicationTransfer(handle, error: nil)
        if case let .success(remaining) = result {
            #expect(remaining == 12)
        } else {
            Issue.record("expected success with remaining budget")
        }
    }
}
#endif

struct WatchConnectivityQueue_test {
    private func interactive(_ identifier: String) -> HAWatchConnectivity.InteractiveImmediateMessage {
        HAWatchConnectivity.InteractiveImmediateMessage(identifier: identifier, reply: { _ in })
    }

    private func sentIdentifiers(_ fake: FakeWCSession) -> [String] {
        fake.sentMessages.compactMap { $0.message["identifier"] as? String }
    }

    @Test func capLimitsConcurrentInteractiveSends() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("one"))
        manager.send(interactive("two"))
        manager.send(interactive("three"))
        #expect(sentIdentifiers(fake) == ["one", "two"])

        // Resolving an in-flight send hands its slot to the queued one.
        fake.sentMessages[0].replyHandler?(HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation())
        #expect(sentIdentifiers(fake) == ["one", "two", "three"])
    }

    @Test func priorityOrdersQueuedSends() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("filler1"))
        manager.send(interactive("filler2"))
        manager.send(interactive("bulk"), priority: .background)
        manager.send(interactive("refresh"), priority: .normal)
        manager.send(interactive("tap"), priority: .userAction)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        fake.sentMessages[0].replyHandler?(reply)
        fake.sentMessages[1].replyHandler?(reply)
        fake.sentMessages[2].replyHandler?(reply)
        #expect(sentIdentifiers(fake) == ["filler1", "filler2", "tap", "refresh", "bulk"])
    }

    @Test func coalescingReplacesQueuedSendWithSameKey() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("filler1"))
        manager.send(interactive("filler2"))
        manager.send(interactive("first"), coalescingKey: "config")
        manager.send(interactive("second"), coalescingKey: "config")

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        fake.sentMessages[0].replyHandler?(reply)
        fake.sentMessages[1].replyHandler?(reply)
        // "first" was replaced while queued; only "second" ever reaches the session.
        #expect(sentIdentifiers(fake) == ["filler1", "filler2", "second"])
    }

    @Test func failedGuardsReleaseTheirSlots() {
        let fake = FakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)

        var errors: [Error] = []
        for identifier in ["a", "b", "c"] {
            manager.send(interactive(identifier), errorHandler: { errors.append($0) })
        }
        // Every guard failure released its slot immediately, so all three errored (none stuck queued).
        #expect(errors.count == 3)
        #expect(fake.sentMessages.isEmpty)

        // And the queue is healthy afterwards: a send with reachability restored goes straight out.
        fake.isReachableProxy = true
        manager.send(interactive("d"))
        #expect(sentIdentifiers(fake) == ["d"])
    }

    @Test func cancellingAQueuedSendWithdrawsIt() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("one"))
        manager.send(interactive("two"))
        var errors: [Error] = []
        let queued = manager.send(interactive("three"), errorHandler: { errors.append($0) })
        manager.send(interactive("four"))

        #expect(manager.cancelQueuedInteractiveSend(queued))
        #expect(manager.cancelQueuedInteractiveSend(queued) == false)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        fake.sentMessages[0].replyHandler?(reply)
        fake.sentMessages[1].replyHandler?(reply)
        #expect(sentIdentifiers(fake) == ["one", "two", "four"])
        #expect(errors.isEmpty)
    }

    @Test func cancellingASendThatAlreadyWentOutChangesNothing() {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        let inFlight = manager.send(interactive("one"))

        #expect(manager.cancelQueuedInteractiveSend(inFlight) == false)
        #expect(sentIdentifiers(fake) == ["one"])
    }

    @Test func aQueuedSendExpiresWhileWaitingForASlot() async throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("one"))
        manager.send(interactive("two"))
        var error: Error?
        let queued = manager.send(interactive("expired"), timeout: 0.05, errorHandler: { error = $0 })
        let reached3 = await waitUntil { error != nil }
        #expect(reached3)

        #expect(error as? HAWatchConnectivity.ConnectivityError == .notSentInTime)
        #expect(manager.cancelQueuedInteractiveSend(queued) == false)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        fake.sentMessages[0].replyHandler?(reply)
        #expect(sentIdentifiers(fake) == ["one", "two"])
    }

    @Test func aSendDequeuedPastItsTimeoutIsNeverSent() async throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("one"))
        manager.send(interactive("two"))
        var errors: [Error] = []
        manager.send(interactive("late"), timeout: 0.05, errorHandler: { errors.append($0) })

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        let freeASlotAfterTheDeadline = {
            Thread.sleep(forTimeInterval: 0.1)
            fake.sentMessages[0].replyHandler?(reply)
        }
        if Thread.isMainThread {
            freeASlotAfterTheDeadline()
        } else {
            DispatchQueue.main.sync(execute: freeASlotAfterTheDeadline)
        }
        let reached4 = await waitUntil { !errors.isEmpty }
        #expect(reached4)
        // The queued send's own expiry is due by now too, and must not report a second time: a short
        // wait only because this checks for nothing.
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(sentIdentifiers(fake) == ["one", "two"])
        #expect(errors.count == 1)
        #expect(errors.first as? HAWatchConnectivity.ConnectivityError == .notSentInTime)

        manager.send(interactive("next"))
        #expect(sentIdentifiers(fake) == ["one", "two", "next"])
    }

    /// The reply timeout runs from when the send was asked for, not from when it left the queue: it
    /// fires `timeout` after queueing, well before `timeout` after the send went out.
    @Test func timeSpentQueuedCountsAgainstTheReplyTimeout() async throws {
        let fake = FakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.send(interactive("one"))
        manager.send(interactive("two"))
        let timeout: TimeInterval = 3
        var error: Error?
        var errorDate: Date?
        let queuedAt = Date()
        manager.send(interactive("waited"), timeout: timeout, errorHandler: {
            error = $0
            errorDate = Date()
        })
        // Time spent in the queue is what this is about, so it is spent on purpose rather than
        // waited out for something to happen.
        try await Task.sleep(nanoseconds: 1_500_000_000)

        let reply = HAWatchConnectivity.ImmediateMessage(identifier: "r").jsonRepresentation()
        fake.sentMessages[0].replyHandler?(reply)
        let sentAt = Date()
        #expect(sentIdentifiers(fake) == ["one", "two", "waited"])
        #expect(error == nil)

        let reached5 = await waitUntil { error != nil }
        #expect(reached5)
        #expect(error as? HAWatchConnectivity.ConnectivityError == .replyTimedOut)
        let firedAfter = try #require(errorDate).timeIntervalSince(queuedAt)
        #expect(firedAfter < sentAt.timeIntervalSince(queuedAt) + timeout)
    }

    @Test func aSendDroppedFromTheQueueDescribesItselfAsNeverSent() {
        let error = HAWatchConnectivity.ConnectivityError.notSentInTime

        #expect(error.errorDescription == "The message waited for a free send slot past its timeout and was not sent")
        #expect((error as NSError).code == 8)
        #expect((error as NSError).domain == HAWatchConnectivity.ConnectivityError.errorDomain)
        #expect(error != HAWatchConnectivity.ConnectivityError.replyTimedOut)
    }

    /// Callers degrade to a background retry on these instead of showing the user an error, so the
    /// classification has to hold for every shape the unreachable error arrives in.
    @Test func unreachableErrorsAreRecognisedThroughEveryWrapping() {
        typealias Subject = HAWatchConnectivity.ConnectivityError
        // The shape WCSession itself hands back (domain WCErrorDomain, code 7007).
        func wcError(_ code: WCError.Code) -> NSError {
            NSError(domain: WCErrorDomain, code: code.rawValue)
        }
        let unreachable = wcError(.notReachable)

        #expect(Subject.isCounterpartUnreachable(Subject.notReachable))
        #expect(Subject.isCounterpartUnreachable(unreachable))
        #expect(Subject.isCounterpartUnreachable(Subject.deliveryFailed(underlying: unreachable)))

        // Real failures must stay failures.
        #expect(!Subject.isCounterpartUnreachable(Subject.replyTimedOut))
        #expect(!Subject.isCounterpartUnreachable(Subject.payloadTooLarge))
        #expect(!Subject.isCounterpartUnreachable(wcError(.payloadTooLarge)))
        #expect(!Subject.isCounterpartUnreachable(Subject.deliveryFailed(underlying: wcError(.deliveryFailed))))
    }
}
