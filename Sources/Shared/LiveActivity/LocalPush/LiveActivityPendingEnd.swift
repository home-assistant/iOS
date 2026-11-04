#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Cross-process hand-off for ending Live Activities. The PushProvider extension has
/// no working ActivityKit, so it enqueues a tag and posts a Darwin signal; the app
/// drains the queue and ends the activity. The persisted queue is the durable path —
/// Darwin does not wake a suspended app, so the app also drains at launch/foreground.
///
/// An end the app cannot apply right away (it is suspended) is not left waiting for the next
/// launch: the extension holds the server's receipt confirm until the app replies through
/// `LiveActivityLocalPushResult`, and re-opens the channel otherwise so the server re-sends the
/// end through APNs, which ends the activity by its push token without waking the app.
enum LiveActivityPendingEnd {
    struct Request: Codable, Equatable {
        let tag: String
        /// Local-push receipt confirm the extension is holding until the app reports that it ended
        /// this activity (see `LiveActivityLocalPushResult`); nil when nothing waits on the reply.
        let confirmID: String?
    }

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityPendingEnd"
    }

    private static let storeKey = "liveActivityPendingEndRequests"
    // Bare tags queued by builds before confirm ids were carried; folded into the store above so an
    // end queued across an update still lands, and a newer start still cancels it.
    private static let legacyStoreKey = "liveActivityPendingEndTags"
    private static let lock = NSLock()

    /// Enqueue an end. Coalesces by tag (the latest confirm id for a tag wins) and cancels any
    /// start queued earlier for the same tag — last writer wins.
    static func append(tag: String, confirmID: String? = nil) {
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
        migrateLegacyTags(in: defaults)
        var requests = load(from: defaults).filter { $0.tag != tag }
        requests.append(Request(tag: tag, confirmID: confirmID))
        store(requests, to: defaults)
        Current.Log.verbose("LiveActivityPendingEnd: enqueued '\(tag)', pending=\(requests.count)")
    }

    /// Hand an end off from the PushProvider extension to the app: enqueue it with the push's
    /// confirm id, if any, and wake the app.
    static func handOff(tag: String, payload: [String: Any]) {
        Current.Log.verbose("Handing off live activity end for tag \(tag) to the app")
        append(tag: tag, confirmID: payload[LocalPushManager.confirmIDUserInfoKey] as? String)
        postDarwinSignal()
    }

    /// Remove a queued end for `tag` (called when a newer start is enqueued for the same tag).
    static func remove(tag: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        migrateLegacyTags(in: defaults)
        let requests = load(from: defaults)
        let remaining = requests.filter { $0.tag != tag }
        guard remaining.count != requests.count else { return }
        store(remaining, to: defaults)
    }

    static func drainAll() -> [Request] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [] }
        migrateLegacyTags(in: defaults)
        let observed = load(from: defaults)
        guard !observed.isEmpty else { return [] }
        // Subtract only the exact requests we read, so a concurrent extension append — whether a
        // different tag or a newer confirm id for a tag we observed — survives instead of being
        // clobbered (the cross-process queue shares no lock); it drains on the next signal/launch.
        let remaining = load(from: defaults).filter { !observed.contains($0) }
        store(remaining, to: defaults)
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

    // Based on HandlerStartOrUpdateLiveActivity.isValidTag, but also rejects empty tags.
    static func isValidTag(_ tag: String) -> Bool {
        guard !tag.isEmpty, tag.count <= 64 else { return false }
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        )
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private static func migrateLegacyTags(in defaults: UserDefaults) {
        guard let tags = defaults.stringArray(forKey: legacyStoreKey) else { return }
        defaults.removeObject(forKey: legacyStoreKey)
        let requests = load(from: defaults)
        let queuedTags = Set(requests.map(\.tag))
        let legacy = tags.filter { !queuedTags.contains($0) }.map { Request(tag: $0, confirmID: nil) }
        store(requests + legacy, to: defaults)
    }

    private static func load(from defaults: UserDefaults) -> [Request] {
        guard let data = defaults.data(forKey: storeKey) else { return [] }
        do {
            return try JSONDecoder().decode([Request].self, from: data)
        } catch {
            Current.Log.error("LiveActivityPendingEnd: failed to decode queue, dropping it: \(error)")
            defaults.removeObject(forKey: storeKey)
            return []
        }
    }

    private static func store(_ requests: [Request], to defaults: UserDefaults) {
        // Encoding plain strings cannot fail.
        guard !requests.isEmpty, let data = try? JSONEncoder().encode(requests) else {
            defaults.removeObject(forKey: storeKey)
            return
        }
        defaults.set(data, forKey: storeKey)
    }
}
#endif
