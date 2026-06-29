#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Cross-process hand-off for ending Live Activities. The PushProvider extension has
/// no working ActivityKit, so it enqueues a tag and posts a Darwin signal; the app
/// drains the queue and ends the activity. The persisted queue is the durable path —
/// Darwin does not wake a suspended app, so the app also drains at launch/foreground.
enum LiveActivityPendingEnd {
    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityPendingEnd"
    }

    private static let storeKey = "liveActivityPendingEndTags"
    private static let lock = NSLock()

    static func append(tag: String) {
        guard isValidTag(tag) else {
            Current.Log.error("LiveActivityPendingEnd: rejected invalid tag '\(tag)'")
            return
        }
        // A newer end supersedes a stale start queued earlier for the same tag. Done before
        // taking our lock so the two queues are never held simultaneously (no lock-order inversion).
        if #available(iOS 17.2, *) {
            LiveActivityPendingStart.remove(tag: tag)
        }
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: storeKey) ?? [])
        tags.insert(tag)
        defaults.set(Array(tags), forKey: storeKey)
        Current.Log.verbose("LiveActivityPendingEnd: enqueued '\(tag)', pending=\(tags.count)")
    }

    /// Remove a queued end for `tag` (called when a newer start is enqueued for the same tag).
    static func remove(tag: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var tags = Set(defaults.stringArray(forKey: storeKey) ?? [])
        guard tags.remove(tag) != nil else { return }
        if tags.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(Array(tags), forKey: storeKey)
        }
    }

    static func drainAll() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        let observed = Set(defaults.stringArray(forKey: storeKey) ?? [])
        guard !observed.isEmpty else { return [] }
        // Subtract only what we read, so a concurrent extension append isn't clobbered.
        let remaining = Set(defaults.stringArray(forKey: storeKey) ?? []).subtracting(observed)
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(Array(remaining), forKey: storeKey)
        }
        return Array(observed)
    }

    // Payload-less wake; the tags travel via the App Group store above.
    static func postDarwinSignal() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(rawValue: darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    // Mirrors HandlerStartOrUpdateLiveActivity.isValidTag.
    static func isValidTag(_ tag: String) -> Bool {
        guard !tag.isEmpty, tag.count <= 64 else { return false }
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
#endif
