import Foundation
@testable import Shared
import Testing
import WatchConnectivity

private final class SessionStateTransferHandle: WCTransferHandle {}

private final class SessionStateFakeWCSession: WCSessionProtocol {
    var delegateProxy: WCSessionDelegate?
    var activationStateProxy: WCSessionActivationState = .activated
    var isReachableProxy = true
    var hasContentPendingProxy = false
    var applicationContextProxy: [String: Any] = [:]
    var receivedApplicationContextProxy: [String: Any] = [:]
    var outstandingUserInfoTransfersProxy: [[String: Any]] = []
    var didActivate = false
    var lastFileHandle: SessionStateTransferHandle?

    func activateProxy() { didActivate = true }

    func sendMessageProxy(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?,
        errorHandler: ((Error) -> Void)?
    ) {}

    func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws {
        applicationContextProxy = applicationContext
    }

    @discardableResult func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        SessionStateTransferHandle()
    }

    @discardableResult func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle {
        let handle = SessionStateTransferHandle()
        lastFileHandle = handle
        return handle
    }

    #if os(iOS)
    var isPairedProxy = true
    var isWatchAppInstalledProxy = true
    var isComplicationEnabledProxy = true
    var remainingComplicationUserInfoTransfersProxy = 3
    var watchDirectoryURLProxy: URL?

    @discardableResult func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle {
        SessionStateTransferHandle()
    }
    #endif
}

/// Collects values an `Observable` delivers on a private serial queue, so a test can flush the
/// queue with `sync {}` instead of sleeping.
private final class DeliveryRecorder<T> {
    let queue = DispatchQueue(label: "WatchConnectivityManagerSessionTests.delivery")
    private(set) var values: [T] = []

    func observe(_ observable: HAWatchConnectivity.Observable<T>) {
        observable.observe(queue: queue) { [weak self] value in
            self?.values.append(value)
        }
    }

    func flushed() -> [T] {
        queue.sync {}
        return values
    }
}

private struct SessionStateTestError: LocalizedError {
    var errorDescription: String? { "boom" }
}

struct WatchConnectivityManagerSessionTests {
    @Test func sessionStateMirrorsActivationState() {
        let fake = SessionStateFakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        fake.activationStateProxy = .notActivated
        #expect(manager.sessionState == .notActivated)
        fake.activationStateProxy = .inactive
        #expect(manager.sessionState == .inactive)
        fake.activationStateProxy = .activated
        #expect(manager.sessionState == .activated)
    }

    @Test func managerWithoutSessionReportsUnsupported() {
        let manager = WatchConnectivityManager(session: nil)

        #expect(manager.isSupported == false)
        #expect(manager.sessionState == .notActivated)
        #expect(manager.currentReachability == .notReachable)
        #expect(manager.hasPendingDataToBeReceived == false)
        #expect(manager.hasOutstandingGuaranteedMessage(identifier: "x") == false)
        #expect(manager.mostRecentlySentContext.content.isEmpty)
        #if os(iOS)
        #expect(manager.currentWatchState == .notPaired)
        #endif
        manager.activate()
    }

    @Test func pendingContentAndOutstandingMessagesComeFromTheSession() {
        let fake = SessionStateFakeWCSession()
        let manager = WatchConnectivityManager(session: fake)
        #expect(manager.isSupported)

        fake.hasContentPendingProxy = true
        #expect(manager.hasPendingDataToBeReceived)

        fake.outstandingUserInfoTransfersProxy = [
            ["identifier": "configPull", "content": [String: Any]()],
            ["unrelated": true],
        ]
        #expect(manager.hasOutstandingGuaranteedMessage(identifier: "configPull"))
        #expect(manager.hasOutstandingGuaranteedMessage(identifier: "other") == false)
    }

    @Test func receivedContextIsCachedAndBroadcast() {
        let manager = WatchConnectivityManager(session: SessionStateFakeWCSession())
        let recorder = DeliveryRecorder<HAWatchConnectivity.Context>()
        recorder.observe(manager.context)

        #expect(manager.mostRecentlyReceivedContext.content.isEmpty)

        manager.receiveApplicationContext(["servers": "data"])

        #expect(manager.mostRecentlyReceivedContext.content["servers"] as? String == "data")
        let delivered = recorder.flushed()
        #expect(delivered.count == 1)
        #expect(delivered.first?.content["servers"] as? String == "data")
    }

    @Test func cacheWithoutOverwriteKeepsANewerContext() {
        let manager = WatchConnectivityManager(session: SessionStateFakeWCSession())

        manager.cacheReceivedContext(["value": 1], overwrite: false)
        manager.cacheReceivedContext(["value": 2], overwrite: false)
        #expect(manager.mostRecentlyReceivedContext.content["value"] as? Int == 1)

        manager.cacheReceivedContext(["value": 3])
        #expect(manager.mostRecentlyReceivedContext.content["value"] as? Int == 3)
    }

    @Test func mostRecentlySentContextReadsTheSession() {
        let fake = SessionStateFakeWCSession()
        fake.applicationContextProxy = ["sent": "yes"]
        let manager = WatchConnectivityManager(session: fake)

        #expect(manager.mostRecentlySentContext.content["sent"] as? String == "yes")
    }

    @Test func activateClaimsTheDelegateAndActivates() {
        let fake = SessionStateFakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        manager.activate()

        #expect(fake.didActivate)
        #expect(fake.delegateProxy === manager)
    }

    @Test func blobFileIsDecodedAndBroadcast() throws {
        let manager = WatchConnectivityManager(session: SessionStateFakeWCSession())
        let recorder = DeliveryRecorder<HAWatchConnectivity.Blob>()
        recorder.observe(manager.blob)

        let blob = HAWatchConnectivity.Blob(identifier: "mirror", content: Data([0x01, 0x02]))
        let data = try #require(blob.dataRepresentation())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchConnectivityManagerSessionTests-\(UUID().uuidString)")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        manager.receiveBlob(fileURL: url, metadata: ["key": "value"])

        let delivered = recorder.flushed()
        #expect(delivered.count == 1)
        #expect(delivered.first?.identifier == "mirror")
        #expect(delivered.first?.content == Data([0x01, 0x02]))
        #expect(delivered.first?.metadata?["key"] as? String == "value")
    }

    @Test func undecodableBlobFileIsIgnored() {
        let manager = WatchConnectivityManager(session: SessionStateFakeWCSession())
        let recorder = DeliveryRecorder<HAWatchConnectivity.Blob>()
        recorder.observe(manager.blob)

        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("WatchConnectivityManagerSessionTests-missing-\(UUID().uuidString)")
        manager.receiveBlob(fileURL: missing, metadata: nil)

        #expect(recorder.flushed().isEmpty)
    }

    @Test func failedFileTransferReportsDeliveryFailure() throws {
        let fake = SessionStateFakeWCSession()
        let manager = WatchConnectivityManager(session: fake)

        var result: Result<Void, Error>?
        manager.transfer(
            HAWatchConnectivity.Blob(identifier: "audio", content: Data([0x01])),
            completion: { result = $0 }
        )
        let handle = try #require(fake.lastFileHandle)
        manager.resolveFileTransfer(handle, error: SessionStateTestError())

        guard case let .failure(error) = result else {
            Issue.record("expected failure")
            return
        }
        let connectivityError = try #require(error as? HAWatchConnectivity.ConnectivityError)
        if case let .deliveryFailed(underlying) = connectivityError {
            #expect(underlying.localizedDescription == "boom")
        } else {
            Issue.record("expected deliveryFailed, got \(connectivityError)")
        }

        // A second resolution of the same handle finds no completion left.
        result = nil
        manager.resolveFileTransfer(handle, error: nil)
        #expect(result == nil)
    }

    @Test func delegateCallbacksBroadcastStateAndReachability() {
        let fake = SessionStateFakeWCSession()
        fake.isReachableProxy = false
        let manager = WatchConnectivityManager(session: fake)
        let states = DeliveryRecorder<HAWatchConnectivity.SessionState>()
        let reachability = DeliveryRecorder<HAWatchConnectivity.Reachability>()
        states.observe(manager.state)
        reachability.observe(manager.reachability)

        manager.session(WCSession.default, activationDidCompleteWith: .activated, error: SessionStateTestError())
        manager.sessionReachabilityDidChange(WCSession.default)

        #expect(states.flushed() == [.activated])
        #expect(reachability.flushed() == [.notReachable, .notReachable])
    }

    #if os(iOS)
    @Test func watchStateCallbacksUpdateTheCachedState() {
        let fake = SessionStateFakeWCSession()
        let manager = WatchConnectivityManager(session: fake)
        let watchStates = DeliveryRecorder<HAWatchConnectivity.WatchState>()
        watchStates.observe(manager.watchState)
        #expect(manager.lastKnownWatchState == .notPaired)

        manager.sessionWatchStateDidChange(WCSession.default)
        #expect(manager.lastKnownWatchState == .paired(.installed(.enabled(numberOfUpdatesAvailableToday: 3), nil)))

        fake.activationStateProxy = .inactive
        let states = DeliveryRecorder<HAWatchConnectivity.SessionState>()
        states.observe(manager.state)
        manager.sessionDidBecomeInactive(WCSession.default)

        #expect(states.flushed() == [.inactive])
        #expect(watchStates.flushed().count == 1)
    }
    #endif

    @Test func delegateMessageCallbacksRouteToObservers() {
        let manager = WatchConnectivityManager(session: SessionStateFakeWCSession())
        let immediate = DeliveryRecorder<HAWatchConnectivity.ImmediateMessage>()
        let interactive = DeliveryRecorder<HAWatchConnectivity.InteractiveImmediateMessage>()
        let guaranteed = DeliveryRecorder<HAWatchConnectivity.GuaranteedMessage>()
        let contexts = DeliveryRecorder<HAWatchConnectivity.Context>()
        immediate.observe(manager.immediateMessage)
        interactive.observe(manager.interactiveImmediateMessage)
        guaranteed.observe(manager.guaranteedMessage)
        contexts.observe(manager.context)

        manager.session(WCSession.default, didReceiveMessage: ["identifier": "wakeup", "content": [String: Any]()])
        manager.session(
            WCSession.default,
            didReceiveMessage: ["identifier": "config", "content": [String: Any]()],
            replyHandler: { _ in }
        )
        manager.session(WCSession.default, didReceiveUserInfo: ["identifier": "sync", "content": [String: Any]()])
        manager.session(WCSession.default, didReceiveApplicationContext: ["key": "value"])

        #expect(immediate.flushed().map(\.identifier) == ["wakeup"])
        #expect(interactive.flushed().map(\.identifier) == ["config"])
        #expect(guaranteed.flushed().map(\.identifier) == ["sync"])
        #expect(contexts.flushed().count == 1)
        #expect(manager.mostRecentlyReceivedContext.content["key"] as? String == "value")
    }
}
