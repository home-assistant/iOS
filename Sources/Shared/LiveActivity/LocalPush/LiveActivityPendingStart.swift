#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation
@preconcurrency import PromiseKit

/// Cross-process hand-off for starting/updating Live Activities. The PushProvider extension
/// has no working ActivityKit, so when a `live_update` notification arrives over the local-push
/// channel it serializes the request and posts a Darwin signal; the app drains the queue and
/// calls `startOrUpdate`. Mirrors `LiveActivityPendingEnd`. The persisted queue is the durable
/// path — Darwin does not wake a suspended app, so the app also drains at launch/foreground.
///
/// ⚠️ A start delivered via local push while the app is suspended therefore only materializes
/// when the app is next active — not in real time. Real-time background starts require APNs
/// push-to-start, which the registry already supports.
@available(iOS 17.2, *)
enum LiveActivityPendingStart {
    /// A serialized start/update request mirroring the arguments of `startOrUpdate`.
    struct Request: Codable, Equatable {
        let tag: String
        let title: String
        let serverWebhookId: String?
        let state: HALiveActivityAttributes.ContentState
        let confirmID: String?
        /// Whether a non-silent update should fire an ActivityKit alert (sound + haptic). Decoded
        /// with a default so a queue serialized by an older build still drains.
        let alert: Bool

        init(
            tag: String,
            title: String,
            serverWebhookId: String?,
            state: HALiveActivityAttributes.ContentState,
            confirmID: String?,
            alert: Bool
        ) {
            self.tag = tag
            self.title = title
            self.serverWebhookId = serverWebhookId
            self.state = state
            self.confirmID = confirmID
            self.alert = alert
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.tag = try container.decode(String.self, forKey: .tag)
            self.title = try container.decode(String.self, forKey: .title)
            self.serverWebhookId = try container.decodeIfPresent(String.self, forKey: .serverWebhookId)
            self.state = try container.decode(HALiveActivityAttributes.ContentState.self, forKey: .state)
            self.confirmID = try container.decodeIfPresent(String.self, forKey: .confirmID)
            self.alert = try container.decodeIfPresent(Bool.self, forKey: .alert) ?? true
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(tag, forKey: .tag)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(serverWebhookId, forKey: .serverWebhookId)
            try container.encode(state, forKey: .state)
            try container.encodeIfPresent(confirmID, forKey: .confirmID)
            try container.encode(alert, forKey: .alert)
        }
    }

    static func confirmLocalPushDelivery(for request: Request) {
        guard let confirmID = request.confirmID, let webhookID = request.serverWebhookId else { return }
        guard let server = Current.servers.all.first(where: { $0.info.connection.webhookID == webhookID }),
              let api = Current.api(for: server) else {
            Current.Log.error("LiveActivityPendingStart: no server for webhook to confirm local push delivery")
            return
        }
        Current.Log.verbose("LiveActivityPendingStart: confirming local push delivery for tag \(request.tag)")
        api.connection.send(.localPushConfirm(webhookID: webhookID, confirmID: confirmID)).promise.cauterize()
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
        var requests = load(from: defaults).filter { $0.tag != request.tag }
        requests.append(request)
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
        let tags = LiveActivityPendingEnd.drainAll()
        guard !tags.isEmpty else { return }
        Current.Log.verbose("LiveActivityPendingEnd: draining \(tags.count) tag(s) in app")
        // Background task so the async dismissal finishes even when backgrounded.
        _ = Current.backgroundTask(withName: "live-activity-pending-end") { _ in
            Promise<Void> { seal in
                Task {
                    for tag in tags {
                        await Current.liveActivityRegistry?.end(tag: tag, dismissalPolicy: .immediate)
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
                        do {
                            let presented = try await Current.liveActivityRegistry?.startOrUpdate(
                                tag: request.tag,
                                title: request.title,
                                serverWebhookId: request.serverWebhookId,
                                state: request.state,
                                alert: request.alert
                            )
                            if presented == true {
                                LiveActivityPendingStart.confirmLocalPushDelivery(for: request)
                            }
                        } catch {
                            Current.Log.error(
                                "LiveActivityPendingStart: startOrUpdate failed for tag \(request.tag): \(error)"
                            )
                        }
                    }
                    DispatchQueue.main.async { seal.fulfill(()) }
                }
            }
        }
    }
}
#endif
