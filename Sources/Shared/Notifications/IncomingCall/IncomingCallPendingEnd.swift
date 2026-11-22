import Foundation

/// Stops a ringing call when Home Assistant sends `clear_notification` with the call's tag, for instance because
/// the caller hung up or the call was answered on another device.
///
/// CallKit belongs to the app. When the command arrives in the PushProvider extension (local push), the tag is
/// queued in the App Group defaults and a Darwin signal wakes the app, which is running while a call rings since
/// CallKit launched it. In the app itself the request is posted in-process. The app also drains the queue when
/// it becomes active, in case a signal was missed.
public enum IncomingCallPendingEnd {
    /// Posted in the app process, `object` is the tag.
    public static let didRequestEnd = Notification.Name("IncomingCallPendingEndDidRequestEnd")

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    public static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".incomingCallPendingEnd"
    }

    private static let storeKey = "incomingCallPendingEndTags"
    private static let lock = NSLock()

    public static func request(tag: String) {
        request(tag: tag, defaults: Current.settingsStore.prefs)
    }

    static func request(tag: String, defaults: UserDefaults) {
        guard IncomingCallRequest.isValidTag(tag) else { return }

        if Current.isAppExtension {
            append(tag: tag, defaults: defaults)
            postDarwinSignal()
        } else {
            NotificationCenter.default.post(name: didRequestEnd, object: tag)
        }
    }

    static func append(tag: String, defaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        var tags = defaults.stringArray(forKey: storeKey) ?? []
        guard !tags.contains(tag) else { return }
        tags.append(tag)
        // A handful of calls at most ever wait here; keep the queue bounded anyway.
        defaults.set(Array(tags.suffix(16)), forKey: storeKey)
    }

    /// The queued tags, removed from the queue.
    public static func drainAll() -> [String] {
        drainAll(defaults: Current.settingsStore.prefs)
    }

    static func drainAll(defaults: UserDefaults) -> [String] {
        lock.lock()
        defer { lock.unlock() }
        let tags = defaults.stringArray(forKey: storeKey) ?? []
        defaults.removeObject(forKey: storeKey)
        return tags.filter(IncomingCallRequest.isValidTag)
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
