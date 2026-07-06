import Foundation
@testable import Shared
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
        try await Task.sleep(nanoseconds: 400_000_000)
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
        try await Task.sleep(nanoseconds: 400_000_000)
        #expect(receivedReply?.identifier == "watchConfigResponse")
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

        try await Task.sleep(nanoseconds: 250_000_000)
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

        try await Task.sleep(nanoseconds: 250_000_000)
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
        try await Task.sleep(nanoseconds: 250_000_000)
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
        try await Task.sleep(nanoseconds: 250_000_000)
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

        var replied = false
        manager.receiveMessage(["identifier": "x"], replyHandler: { _ in replied = true })
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(replied == true)
        #expect(interactiveBox.count == 0)
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
