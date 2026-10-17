#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// The app's reply to a Live Activity start handed off over local push: whether it presented it.
///
/// The extension holds the server's receipt confirm until this arrives (see
/// `LiveActivityLocalPushConfirmTracker`). `presented` confirms the push; `notPresented` means
/// ActivityKit refused because the app is in the background, so the extension re-opens the channel
/// and the server re-sends the push through APNs instead. Mirrors `LiveActivityPendingStart`: the
/// outcome travels through the App Group store and a payload-less Darwin signal.
enum LiveActivityLocalPushResult {
    enum Outcome: String {
        case presented
        case notPresented
    }

    // Namespaced by App Group id so dev/beta/release installs never cross-signal.
    static var darwinNotificationName: String {
        AppConstants.AppGroupID + ".liveActivityLocalPushResult"
    }

    private static let storeKey = "liveActivityLocalPushResults"
    private static let lock = NSLock()

    static func record(_ outcome: Outcome, confirmID: String) {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return }
        var results = defaults.dictionary(forKey: storeKey) as? [String: String] ?? [:]
        results[confirmID] = outcome.rawValue
        defaults.set(results, forKey: storeKey)
    }

    /// Remove and return the outcomes recorded for `confirmIDs`. Other entries belong to another
    /// server's manager and are left in place.
    static func take(confirmIDs: Set<String>) -> [String: Outcome] {
        lock.lock()
        defer { lock.unlock() }
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID),
              var remaining = defaults.dictionary(forKey: storeKey) as? [String: String] else { return [:] }
        var taken: [String: Outcome] = [:]
        for confirmID in confirmIDs {
            guard let raw = remaining.removeValue(forKey: confirmID), let outcome = Outcome(rawValue: raw) else {
                continue
            }
            taken[confirmID] = outcome
        }
        if remaining.isEmpty {
            defaults.removeObject(forKey: storeKey)
        } else {
            defaults.set(remaining, forKey: storeKey)
        }
        return taken
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
#endif
