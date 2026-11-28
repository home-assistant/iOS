import Foundation

/// Stops a ringing call when Home Assistant sends `clear_notification` with the call's tag, for instance because
/// the caller hung up or the call was answered on another device.
///
/// CallKit belongs to the app. When the command arrives in the PushProvider extension (local push), the request
/// is queued in the App Group defaults and a Darwin signal wakes the app, which is running while a call rings
/// since CallKit launched it. In the app itself the request is posted in-process. The app also drains the queue
/// when it becomes active and right after it reports a call, in case a signal arrived before it was listening.
///
/// Each request carries the server and the time it was made (`IncomingCallEndRequest`), so it only ends a call
/// from that server that was already ringing; queued requests expire after `lifetime`.
public enum IncomingCallPendingEnd {
    /// Posted in the app process, `object` is the `IncomingCallEndRequest`.
    public static let didRequestEnd = Notification.Name("IncomingCallPendingEndDidRequestEnd")

    /// Longer than a call can ring (`IncomingCallRequest.timeoutRange`), so a request never outlives its call.
    public static let lifetime: TimeInterval = 5 * 60

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    public static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".incomingCallPendingEnd"
    }

    private static let storeKey = "incomingCallPendingEnds"

    public static func request(tag: String, webhookID: String?) {
        // Nothing can be ringing when calls do not ring: don't queue requests for users who never turned it on.
        guard IncomingCallFeature.isEnabled else { return }
        request(
            .init(tag: tag, webhookID: webhookID, date: Current.date()),
            defaults: Current.settingsStore.prefs
        )
    }

    static func request(_ endRequest: IncomingCallEndRequest, defaults: UserDefaults) {
        guard IncomingCallRequest.isValidTag(endRequest.tag) else { return }

        if Current.isAppExtension {
            append(endRequest, defaults: defaults)
            postDarwinSignal()
        } else {
            NotificationCenter.default.post(name: didRequestEnd, object: endRequest)
        }
    }

    static func append(_ endRequest: IncomingCallEndRequest, defaults: UserDefaults) {
        IncomingCallFileLock.withLock {
            var requests = load(defaults: defaults, now: endRequest.date)
            requests.removeAll { $0.tag == endRequest.tag && $0.webhookID == endRequest.webhookID }
            requests.append(endRequest)
            // A handful of calls at most ever wait here; keep the queue bounded anyway.
            store(Array(requests.suffix(16)), defaults: defaults)
        }
    }

    /// The queued requests that have not expired, removed from the queue in the same step, so a request the
    /// extension queues meanwhile is either returned now or left for the next drain.
    public static func drainAll() -> [IncomingCallEndRequest] {
        drainAll(defaults: Current.settingsStore.prefs, now: Current.date())
    }

    static func drainAll(defaults: UserDefaults, now: Date) -> [IncomingCallEndRequest] {
        IncomingCallFileLock.withLock {
            let requests = load(defaults: defaults, now: now)
            defaults.removeObject(forKey: storeKey)
            return requests
        }
    }

    private static func load(defaults: UserDefaults, now: Date) -> [IncomingCallEndRequest] {
        let stored = defaults.array(forKey: storeKey) as? [[String: Any]] ?? []
        return stored
            .compactMap(IncomingCallEndRequest.init(dictionary:))
            .filter { now.timeIntervalSince($0.date) < lifetime }
    }

    private static func store(_ requests: [IncomingCallEndRequest], defaults: UserDefaults) {
        if requests.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(requests.map(\.dictionary), forKey: storeKey)
        }
    }

    static func postDarwinSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }
}
