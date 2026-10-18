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

    // One key per confirm id: the app writes and the extension consumes from separate processes,
    // so a shared collection rewritten by both could drop a reply.
    private static let keyPrefix = "liveActivityLocalPushResult."

    static func record(_ outcome: Outcome, confirmID: String) {
        UserDefaults(suiteName: AppConstants.AppGroupID)?.set(outcome.rawValue, forKey: keyPrefix + confirmID)
    }

    /// Remove and return the outcomes recorded for `confirmIDs`.
    static func take(confirmIDs: Set<String>) -> [String: Outcome] {
        guard let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else { return [:] }
        var taken: [String: Outcome] = [:]
        for confirmID in confirmIDs {
            let key = keyPrefix + confirmID
            guard let raw = defaults.string(forKey: key) else { continue }
            defaults.removeObject(forKey: key)
            taken[confirmID] = Outcome(rawValue: raw)
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
