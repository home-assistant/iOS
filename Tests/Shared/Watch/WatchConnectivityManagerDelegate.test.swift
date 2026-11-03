import Foundation
@testable import Shared
import Testing
import WatchConnectivity

/// The `WCSessionDelegate` entry points of `WatchConnectivityManager` and its `WCSession` conformance.
/// Each test owns its manager and a fake session; the delegate methods only use the `WCSession` argument
/// as an identity, so the (never activated) default session stands in for it.
struct WatchConnectivityManagerDelegateTests {
    private final class Handle: WCTransferHandle {}

    private final class FakeSession: WCSessionProtocol {
        var delegateProxy: WCSessionDelegate?
        var activationStateProxy: WCSessionActivationState = .activated
        var isReachableProxy = true
        var hasContentPendingProxy = true
        var applicationContextProxy: [String: Any] = ["sent": 1]
        var receivedApplicationContextProxy: [String: Any] = ["primed": true]
        var outstandingUserInfoTransfersProxy: [[String: Any]] = []
        var activated = false
        var files: [(URL, [String: Any]?)] = []

        func activateProxy() { activated = true }
        func sendMessageProxy(
            _ message: [String: Any],
            replyHandler: (([String: Any]) -> Void)?,
            errorHandler: ((Error) -> Void)?
        ) {}
        func updateApplicationContextProxy(_ applicationContext: [String: Any]) throws {}
        func transferUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle { Handle() }
        func transferFileProxy(_ file: URL, metadata: [String: Any]?) -> WCTransferHandle {
            files.append((file, metadata))
            return Handle()
        }

        var isPairedProxy = true
        var isWatchAppInstalledProxy = true
        var isComplicationEnabledProxy = true
        var remainingComplicationUserInfoTransfersProxy = 7
        var watchDirectoryURLProxy: URL? = URL(fileURLWithPath: "/tmp/watch")
        func transferCurrentComplicationUserInfoProxy(_ userInfo: [String: Any]) -> WCTransferHandle { Handle() }
    }

    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [T] = []
        func append(_ value: T) { lock.lock(); values.append(value); lock.unlock() }
        var all: [T] { lock.lock(); defer { lock.unlock() }; return values }
    }

    private func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            guard Date() < deadline else { return false }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return true
    }

    private func expectEventually(
        _ condition: () -> Bool,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let met = await waitUntil(condition)
        #expect(met, sourceLocation: sourceLocation)
    }

    private var wcSession: WCSession { WCSession.default }
    /// Observers run on one serial queue so their deliveries keep the order they were notified in.
    private let serial = DispatchQueue(label: "watch-connectivity-delegate-test")

    @Test func lifecycleCallbacksBroadcastState() async {
        let fake = FakeSession()
        let manager = WatchConnectivityManager(session: fake)
        let states = Box<HAWatchConnectivity.SessionState>()
        let reachabilities = Box<HAWatchConnectivity.Reachability>()
        let watchStates = Box<HAWatchConnectivity.WatchState>()
        manager.state.observe(queue: serial) { states.append($0) }
        manager.reachability.observe(queue: serial) { reachabilities.append($0) }
        manager.watchState.observe(queue: serial) { watchStates.append($0) }

        manager.session(
            wcSession,
            activationDidCompleteWith: .activated,
            error: NSError(domain: "test", code: 1)
        )
        manager.sessionReachabilityDidChange(wcSession)
        fake.activationStateProxy = .inactive
        manager.sessionDidBecomeInactive(wcSession)
        fake.isComplicationEnabledProxy = false
        manager.sessionWatchStateDidChange(wcSession)

        await expectEventually { states.all.count == 2 && reachabilities.all.count == 2 && watchStates.all.count == 2 }
        #expect(states.all == [.activated, .inactive])
        #expect(reachabilities.all == [.immediatelyReachable, .immediatelyReachable])
        #expect(manager.lastKnownWatchState == .paired(.installed(.notEnabled, URL(fileURLWithPath: "/tmp/watch"))))
        #expect(watchStates.all.first?.numberOfComplicationUpdatesAvailableToday == 7)
    }

    @Test func activateClaimsTheSessionAndPrimesTheReceivedContext() async {
        let fake = FakeSession()
        let manager = WatchConnectivityManager(session: fake)
        manager.activate()
        #expect(fake.activated)
        #expect(fake.delegateProxy === manager)
        await expectEventually { manager.mostRecentlyReceivedContext.content["primed"] as? Bool == true }
        #expect(manager.mostRecentlySentContext.content["sent"] as? Int == 1)
        #expect(manager.hasPendingDataToBeReceived)
    }

    @Test func incomingMessagesAreRouted() async {
        let manager = WatchConnectivityManager(session: FakeSession())
        let immediate = Box<String>()
        let interactive = Box<String>()
        let guaranteed = Box<String>()
        let contexts = Box<Int>()
        manager.immediateMessage.observe(queue: serial) { immediate.append($0.identifier) }
        manager.interactiveImmediateMessage.observe(queue: serial) { interactive.append($0.identifier) }
        manager.guaranteedMessage.observe(queue: serial) { guaranteed.append($0.identifier) }
        manager.context.observe(queue: serial) { contexts.append($0.content["n"] as? Int ?? -1) }

        manager.session(
            wcSession,
            didReceiveMessage: HAWatchConnectivity.ImmediateMessage(identifier: "one-way").jsonRepresentation()
        )
        let replies = Box<[String: Any]>()
        manager.session(
            wcSession,
            didReceiveMessage: HAWatchConnectivity.ImmediateMessage(identifier: "ask").jsonRepresentation(),
            replyHandler: { replies.append($0) }
        )
        manager.session(wcSession, didReceiveMessage: ["garbage": true], replyHandler: { replies.append($0) })
        manager.session(
            wcSession,
            didReceiveUserInfo: HAWatchConnectivity.GuaranteedMessage(identifier: "queued").jsonRepresentation()
        )
        manager.session(wcSession, didReceiveApplicationContext: ["n": 3])

        await expectEventually {
            immediate.all == ["one-way"] && interactive.all == ["ask"] && guaranteed.all == ["queued"]
                && contexts.all == [3]
        }
        #expect(replies.all.count == 1, "only the undecodable message is answered immediately")
        #expect(manager.mostRecentlyReceivedContext.content["n"] as? Int == 3)
    }

    @Test func stagedBlobsAreDecodedOnReceipt() async throws {
        let fake = FakeSession()
        let manager = WatchConnectivityManager(session: fake)
        let blobs = Box<HAWatchConnectivity.Blob>()
        manager.blob.observe(queue: serial) { blobs.append($0) }

        manager.transfer(HAWatchConnectivity.Blob(identifier: "logs", content: Data([1, 2, 3])), completion: { _ in })
        let (url, metadata) = try #require(fake.files.first)
        manager.receiveBlob(fileURL: url, metadata: metadata)
        manager.receiveBlob(fileURL: URL(fileURLWithPath: "/nonexistent/blob"), metadata: nil)

        await expectEventually { blobs.all.count == 1 }
        #expect(blobs.all.first?.identifier == "logs")
        #expect(blobs.all.first?.content == Data([1, 2, 3]))
    }

    @Test func outstandingGuaranteedMessagesAreDetected() {
        let fake = FakeSession()
        let manager = WatchConnectivityManager(session: fake)
        fake.outstandingUserInfoTransfersProxy = [
            HAWatchConnectivity.GuaranteedMessage(identifier: "config").jsonRepresentation(),
        ]
        #expect(manager.hasOutstandingGuaranteedMessage(identifier: "config"))
        #expect(!manager.hasOutstandingGuaranteedMessage(identifier: "other"))
        #expect(!WatchConnectivityManager(session: nil).hasOutstandingGuaranteedMessage(identifier: "config"))
    }

    @Test func watchStateDerivesFromTheSession() {
        let fake = FakeSession()
        let manager = WatchConnectivityManager(session: fake)
        #expect(manager.currentWatchState == .paired(.installed(
            .enabled(numberOfUpdatesAvailableToday: 7),
            URL(fileURLWithPath: "/tmp/watch")
        )))
        fake.isWatchAppInstalledProxy = false
        #expect(manager.currentWatchState == .paired(.notInstalled))
        fake.isPairedProxy = false
        #expect(manager.currentWatchState == .notPaired)
        #expect(manager.currentWatchState.appState == .notInstalled)
        #expect(manager.currentWatchState.complicationState == .notEnabled)
        #expect(manager.currentWatchState.numberOfComplicationUpdatesAvailableToday == 0)
    }

    /// Reads every proxy of the real `WCSession` conformance. The default session is never activated
    /// here, so the values are its inert defaults.
    @Test func realSessionConformanceIsReadable() {
        let session: WCSessionProtocol = WCSession.default
        _ = session.delegateProxy
        _ = session.activationStateProxy
        _ = session.isReachableProxy
        _ = session.hasContentPendingProxy
        _ = session.applicationContextProxy
        _ = session.receivedApplicationContextProxy
        _ = session.outstandingUserInfoTransfersProxy
        _ = session.isPairedProxy
        _ = session.isWatchAppInstalledProxy
        _ = session.isComplicationEnabledProxy
        _ = session.remainingComplicationUserInfoTransfersProxy
        _ = session.watchDirectoryURLProxy

        let manager = WatchConnectivityManager(session: session)
        #expect(manager.isSupported)
        _ = manager.sessionState
        _ = manager.currentReachability
        _ = manager.currentWatchState
    }
}
