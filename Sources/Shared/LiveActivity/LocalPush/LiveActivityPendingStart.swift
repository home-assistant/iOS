#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@preconcurrency import PromiseKit

/// Cross-process hand-off for starting/updating Live Activities. The PushProvider extension
/// has no working ActivityKit, so when a `live_update` notification arrives over the local-push
/// channel it serializes the request and posts a Darwin signal; the app drains the queue and
/// calls `startOrUpdate`. Mirrors `LiveActivityPendingEnd`. The persisted queue is the durable
/// path — Darwin does not wake a suspended app, so the app also drains at launch/foreground.
///
/// A start the app cannot show right away (it is suspended, or in the background where ActivityKit
/// refuses) is not lost: the extension holds the server's receipt confirm until the app replies
/// through `LiveActivityLocalPushResult`, and re-opens the channel otherwise so the server re-sends
/// the push through APNs push-to-start, which does reach a backgrounded app.
@available(iOS 17.2, *)
enum LiveActivityPendingStart {
    /// A serialized start/update request mirroring the arguments of `startOrUpdate`.
    struct Request: Codable, Equatable {
        let tag: String
        let title: String
        let serverWebhookId: String?
        let state: HALiveActivityAttributes.ContentState
        let relevanceScore: Double?
        /// Local-push receipt confirm the extension is holding until the app reports whether it
        /// presented this request (see `LiveActivityLocalPushResult`); nil for APNs deliveries.
        let confirmID: String?
        /// Whether a non-silent update should fire an ActivityKit alert (sound + haptic). Decoded
        /// with a default so a queue serialized by an older build still drains.
        let alert: Bool

        // Declared explicitly: providing both init(from:) and encode(to:) opts out of synthesis.
        private enum CodingKeys: String, CodingKey {
            case tag, title, serverWebhookId, state, relevanceScore, confirmID, alert
        }

        init(
            tag: String,
            title: String,
            serverWebhookId: String?,
            state: HALiveActivityAttributes.ContentState,
            relevanceScore: Double? = nil,
            confirmID: String? = nil,
            alert: Bool
        ) {
            self.tag = tag
            self.title = title
            self.serverWebhookId = serverWebhookId
            self.state = state
            self.relevanceScore = relevanceScore
            self.confirmID = confirmID
            self.alert = alert
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.tag = try container.decode(String.self, forKey: .tag)
            self.title = try container.decode(String.self, forKey: .title)
            self.serverWebhookId = try container.decodeIfPresent(String.self, forKey: .serverWebhookId)
            self.state = try container.decode(HALiveActivityAttributes.ContentState.self, forKey: .state)
            self.relevanceScore = try container.decodeIfPresent(Double.self, forKey: .relevanceScore)
            self.confirmID = try container.decodeIfPresent(String.self, forKey: .confirmID)
            self.alert = try container.decodeIfPresent(Bool.self, forKey: .alert) ?? true
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tag, forKey: .tag)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(serverWebhookId, forKey: .serverWebhookId)
            try container.encode(state, forKey: .state)
            try container.encodeIfPresent(relevanceScore, forKey: .relevanceScore)
            try container.encodeIfPresent(confirmID, forKey: .confirmID)
            try container.encode(alert, forKey: .alert)
        }

        func inheritingRelevanceScore(from previous: Request?) -> Request {
            guard relevanceScore == nil, let inherited = previous?.relevanceScore else { return self }
            return Request(
                tag: tag,
                title: title,
                serverWebhookId: serverWebhookId,
                state: state,
                relevanceScore: inherited,
                confirmID: confirmID,
                alert: alert
            )
        }
    }

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityPendingStart"
    }

    private static let storeKey = "liveActivityPendingStartRequests"
    private static let lock = NSLock()

    /// Enqueue a start/update request. Coalesces by tag (the latest state for a tag wins, so a
    /// burst of updates collapses to the freshest) and cancels any end queued earlier for the
    /// same tag — last writer wins.
    static func append(_ request: Request) {
        guard LiveActivityPendingEnd.isValidTag(request.tag) else {
            Current.Log.error("LiveActivityPendingStart: rejected invalid tag '\(request.tag)'")
            return
        }
        // A newer start supersedes a stale end queued earlier. Done before taking our lock so the
        // two queues are never held simultaneously (no lock-order inversion).
        LiveActivityPendingEnd.remove(tag: request.tag)
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        let queued = load(from: defaults)
        var requests = queued.filter { $0.tag != request.tag }
        requests.append(request.inheritingRelevanceScore(from: queued.first { $0.tag == request.tag }))
        store(requests, to: defaults)
        Current.Log.verbose("LiveActivityPendingStart: enqueued '\(request.tag)', pending=\(requests.count)")
    }

    /// Remove a queued start for `tag` (called when a newer end is enqueued for the same tag).
    static func remove(tag: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        let requests = load(from: defaults)
        let remaining = requests.filter { $0.tag != tag }
        guard remaining.count != requests.count else { return }
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            store(remaining, to: defaults)
        }
    }

    static func drainAll() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        let observed = load(from: defaults)
        guard !observed.isEmpty else { return [] }
        // Subtract only the exact requests we read, so a concurrent extension write — whether a
        // different tag or a fresher state for a tag we observed — survives instead of being
        // clobbered (the cross-process queue shares no lock); it drains on the next signal/launch.
        let remaining = load(from: defaults).filter { !observed.contains($0) }
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            store(remaining, to: defaults)
        }
        return observed
    }

    // Payload-less wake; the requests travel via the App Group store above.
    static func postDarwinSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    private static func load(from defaults: UserDefaults) -> [Request] {
        guard let data = defaults.data(forKey: storeKey) else { return [] }
        do {
            return try JSONDecoder().decode([Request].self, from: data)
        } catch {
            Current.Log.error("LiveActivityPendingStart: failed to decode queue, dropping it: \(error)")
            defaults.removeObject(forKey: storeKey)
            return []
        }
    }

    private static func store(_ requests: [Request], to defaults: UserDefaults) {
        do {
            let data = try JSONEncoder().encode(requests)
            defaults.set(data, forKey: storeKey)
        } catch {
            Current.Log.error("LiveActivityPendingStart: failed to encode queue: \(error)")
        }
    }
}

/// App-side drain for `LiveActivityPendingEnd`. Retain one instance to keep the Darwin
/// observer registered.
@available(iOS 17.2, *)
public final class LiveActivityPendingEndObserver {
    public init() {
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // C callback can't capture self; re-derive it (see DeviceWrapperBatteryObserver).
            guard let observer else { return }
            Unmanaged<LiveActivityPendingEndObserver>.fromOpaque(observer)
                .takeUnretainedValue()
                .drain()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            LiveActivityPendingEnd.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    public func drain() {
        Self.drain()
    }

    public static func drain() {
        let requests = LiveActivityPendingEnd.drainAll()
        guard !requests.isEmpty else { return }
        Current.Log.verbose("LiveActivityPendingEnd: draining \(requests.count) tag(s) in app")
        // Background task so the async dismissal finishes even when backgrounded.
        _ = Current.backgroundTask(withName: "live-activity-pending-end") { _ in
            Promise<Void> { seal in
                Task {
                    for request in requests {
                        await Current.liveActivityRegistry?.end(tag: request.tag, dismissalPolicy: .immediate)
                        // Ending works in the background too, so a running app always applies it.
                        if let confirmID = request.confirmID {
                            LiveActivityLocalPushResult.record(.presented, confirmID: confirmID)
                        }
                    }
                    if requests.contains(where: { $0.confirmID != nil }) {
                        LiveActivityLocalPushResult.postDarwinSignal()
                    }
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
    }
}

/// App-side drain for `LiveActivityPendingStart`. Retain one instance to keep the Darwin
/// observer registered.
@available(iOS 17.2, *)
public final class LiveActivityPendingStartObserver {
    public init() {
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            // C callback can't capture self; re-derive it (see DeviceWrapperBatteryObserver).
            guard let observer else { return }
            Unmanaged<LiveActivityPendingStartObserver>.fromOpaque(observer)
                .takeUnretainedValue()
                .drain()
        }
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            callback,
            LiveActivityPendingStart.darwinNotificationName as CFString,
            nil,
            .coalesce
        )
    }

    deinit {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            nil,
            nil
        )
    }

    public func drain() {
        Self.drain()
    }

    public static func drain() {
        let requests = LiveActivityPendingStart.drainAll()
        guard !requests.isEmpty else { return }
        Current.Log.verbose("LiveActivityPendingStart: draining \(requests.count) request(s) in app")
        // Background task so the async start/update finishes even when backgrounded.
        _ = Current.backgroundTask(withName: "live-activity-pending-start") { _ in
            Promise<Void> { seal in
                Task {
                    for request in requests {
                        let presented = await startOrUpdate(request)
                        // Tell the extension whether to confirm the push or have it re-sent via APNs.
                        if let confirmID = request.confirmID {
                            LiveActivityLocalPushResult.record(
                                presented ? .presented : .notPresented,
                                confirmID: confirmID
                            )
                        }
                    }
                    if requests.contains(where: { $0.confirmID != nil }) {
                        LiveActivityLocalPushResult.postDarwinSignal()
                    }
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
    }

    private static func startOrUpdate(_ request: LiveActivityPendingStart.Request) async -> Bool {
        do {
            return try await Current.liveActivityRegistry?.startOrUpdate(
                tag: request.tag,
                title: request.title,
                serverWebhookId: request.serverWebhookId,
                state: request.state,
                relevanceScore: request.relevanceScore,
                alert: request.alert
            ) ?? false
        } catch {
            Current.Log.error("LiveActivityPendingStart: startOrUpdate failed for tag \(request.tag): \(error)")
            return false
        }
    }
}
#endif
