#if canImport(ActivityKit)
import ActivityKit
import Foundation
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// What the registry does without a running Live Activity to drive: starts the device refuses,
/// ends for tags it does not track, and the token release it performs on relaunch.
///
/// `.sharedState`: the tests swap `Current.servers` and `Current.webhooks`, and the token release
/// reads and writes the app group's list of reported tags. Each test only touches tags of its own,
/// and the fake webhook refuses to confirm any other tag, so a tag another test recorded is never
/// released from under it.
@Suite(.sharedState)
struct LiveActivityRegistryLifecycleTests {
    /// A logic-test process can't present a Live Activity: the start is either refused up front
    /// (activities disabled) or by ActivityKit itself, and in both cases nothing is left reserved,
    /// so the same tag can be tried again.
    @available(iOS 17.2, *)
    @Test func aStartTheDeviceRefusesLeavesNothingBehind() async {
        let registry = LiveActivityRegistry()
        let tag = "a5-start-\(UUID().uuidString)"
        let state = HALiveActivityAttributes.ContentState(message: "Washing", chronometer: true)

        for attempt in 0 ..< 2 {
            do {
                let started = try await registry.startOrUpdate(
                    tag: tag,
                    title: "Laundry",
                    serverWebhookId: nil,
                    state: state,
                    relevanceScore: 0.8,
                    alert: true
                )
                // A refusal that kept the reservation would make the second attempt look like a
                // duplicate start, which reports `true`.
                #expect(!started, "attempt \(attempt)")
                if started {
                    await registry.end(tag: tag, dismissalPolicy: .immediate)
                }
            } catch {
                // ActivityKit rejected the request; the reservation was released.
            }
        }
        await registry.end(tag: tag, dismissalPolicy: .default)
    }

    @available(iOS 17.2, *)
    @Test func endingAnUntrackedTagIsHarmless() async {
        let registry = LiveActivityRegistry()
        await registry.end(tag: "a5-unknown-\(UUID().uuidString)", dismissalPolicy: .immediate)
        await registry.end(tag: "a5-unknown-\(UUID().uuidString)")
        _ = LiveActivityRegistry.storedPushToStartToken
    }

    /// On relaunch, a tag Core still holds a token for but that no longer has a running activity is
    /// released with every server, and forgotten once they all confirm.
    @available(iOS 17.2, *)
    @Test func relaunchReleasesTokensForActivitiesThatAreGone() async {
        let tag = "a5-stale-\(UUID().uuidString)"
        let released = Released()
        await withFakes(confirming: tag, released: released) {
            Self.remember(tag)
            defer { Self.forget(tag) }
            // Held for the whole wait: the confirmation reaches the registry through a weak reference.
            let registry = LiveActivityRegistry()
            await registry.reattach()

            // The release is confirmed asynchronously; the tag is gone once it has been.
            let deadline = Date().addingTimeInterval(10)
            while LiveActivityRegistry.hasReportedToken(forTag: tag), Date() < deadline {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            #expect(!LiveActivityRegistry.hasReportedToken(forTag: tag))
            withExtendedLifetime(registry) {}
        }
        #expect(released.tags.allSatisfy { $0 == tag || !$0.hasPrefix("a5-") })
    }

    /// A release a server does not confirm keeps the tag, so the next launch tries again.
    @available(iOS 17.2, *)
    @Test func anUnconfirmedReleaseIsRetriedNextLaunch() async {
        let tag = "a5-unconfirmed-\(UUID().uuidString)"
        let released = Released()
        await withFakes(confirming: "a5-none", released: released) {
            Self.remember(tag)
            defer { Self.forget(tag) }
            // Held until the outcome is handled: it reaches the registry through a weak reference.
            let registry = LiveActivityRegistry()
            await registry.reattach()

            // `reattach()` sends the release before it returns; the refusal is handled on the main queue.
            #expect(released.tags.filter { $0 == tag }.count == 1)
            let refusalHandled = await Self.drainMainQueue()
            #expect(refusalHandled)
            #expect(LiveActivityRegistry.hasReportedToken(forTag: tag))
            withExtendedLifetime(registry) {}

            // The next launch releases it again.
            await LiveActivityRegistry().reattach()
            #expect(released.tags.filter { $0 == tag }.count == 2)
            let retryHandled = await Self.drainMainQueue()
            #expect(retryHandled)
            #expect(LiveActivityRegistry.hasReportedToken(forTag: tag))
        }
    }

    /// Lets the main queue run what was put on it so far. Returns `false` if it did not get there in time.
    private static func drainMainQueue() async -> Bool {
        let drained = Released()
        DispatchQueue.main.async { drained.append("drained") }
        let deadline = Date().addingTimeInterval(10)
        while drained.tags.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return !drained.tags.isEmpty
    }

    @available(iOS 17.2, *)
    @Test func theDefaultRemoteStartObservationDoesNothing() async {
        await MinimalRegistry().startObservingRemoteActivityStarts()
    }

    // MARK: - Helpers

    /// Installs one server and a webhook manager that confirms the dismissal of `confirming` only.
    private func withFakes(confirming tag: String, released: Released, _ body: () async -> Void) async {
        let previousServers = Current.servers
        let previousWebhooks = Current.webhooks
        defer {
            Current.servers = previousServers
            Current.webhooks = previousWebhooks
        }
        let servers = FakeServerManager()
        _ = servers.addFake()
        Current.servers = servers
        let webhooks = ReleaseRecordingWebhooks(confirming: tag, released: released)
        Current.webhooks = webhooks
        await body()
    }

    @available(iOS 17.2, *)
    private static func remember(_ tag: String) {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: LiveActivityRegistry.reportedTokenTagsKey) ?? [])
        tags.insert(tag)
        defaults.set(Array(tags), forKey: LiveActivityRegistry.reportedTokenTagsKey)
    }

    @available(iOS 17.2, *)
    private static func forget(_ tag: String) {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: LiveActivityRegistry.reportedTokenTagsKey) ?? [])
        guard tags.remove(tag) != nil else { return }
        defaults.set(Array(tags), forKey: LiveActivityRegistry.reportedTokenTagsKey)
    }

    /// Confirms the dismissal of one tag and refuses every other, recording each one it is sent.
    private final class ReleaseRecordingWebhooks: WebhookManager {
        private let confirmedTag: String
        private let released: Released

        init(confirming tag: String, released: Released) {
            self.confirmedTag = tag
            self.released = released
            super.init()
        }

        override func sendEphemeral(server: Server, request: WebhookRequest) -> Promise<Void> {
            answer(request)
        }

        override func sendEphemeral<ResponseType>(
            server: Server,
            request: WebhookRequest,
            overrideURL: URL? = nil
        ) -> Promise<ResponseType> {
            answer(request).map { _ in
                guard let value = () as? ResponseType else { throw Released.Refusal() }
                return value
            }
        }

        private func answer(_ request: WebhookRequest) -> Promise<Void> {
            let tag = (request.data as? [String: Any])?["tag"] as? String ?? ""
            released.append(tag)
            return tag == confirmedTag ? .value(()) : .init(error: Released.Refusal())
        }
    }

    private final class Released: @unchecked Sendable {
        struct Refusal: Error {}

        private let lock = NSLock()
        private var released: [String] = []

        var tags: [String] {
            lock.lock()
            defer { lock.unlock() }
            return released
        }

        func append(_ tag: String) {
            lock.lock()
            released.append(tag)
            lock.unlock()
        }
    }

    @available(iOS 17.2, *)
    private final class MinimalRegistry: LiveActivityRegistryProtocol {
        func startOrUpdate(
            tag: String,
            title: String,
            serverWebhookId: String?,
            state: HALiveActivityAttributes.ContentState,
            relevanceScore: Double?,
            alert: Bool
        ) async throws -> Bool { false }

        func end(tag: String, dismissalPolicy: ActivityUIDismissalPolicy) async {}

        func reattach() async {}

        func startObservingPushToStartToken() async {}
    }
}
#endif
