#if canImport(ActivityKit)
import ActivityKit
import Foundation
import PromiseKit

// MARK: - HandlerStartOrUpdateLiveActivity

/// Handles `live_activity: true` notifications by starting or updating a Live Activity.
///
/// Triggered two ways:
///   1. `homeassistant.command == "live_activity"` (message: live_activity in YAML)
///   2. `homeassistant.live_activity == true` (data.live_activity: true in YAML)
///
/// Notification payload fields mirror the Android companion app:
///   tag, title, message, critical_text, progress, progress_max,
///   chronometer, when, when_relative, notification_icon, notification_icon_color
@available(iOS 16.2, *)
struct HandlerStartOrUpdateLiveActivity: NotificationCommandHandler {
    private enum ValidationError: Error {
        case missingTag
        case missingTitle
        case invalidTag
    }

    func handle(_ payload: [String: Any]) -> Promise<Void> {
        // PushProvider (NEAppPushProvider) runs in a separate OS process — ActivityKit is
        // unavailable there. The same notification will be re-delivered to the main app via
        // UNUserNotificationCenter, where it will be handled correctly.
        guard !Current.isAppExtension else {
            Current.Log.verbose("HandlerStartOrUpdateLiveActivity: skipping in app extension, will handle in main app")
            return .value(())
        }

        return Promise { seal in
            Task {
                do {
                    guard let tag = payload["tag"] as? String, !tag.isEmpty else {
                        throw ValidationError.missingTag
                    }

                    guard Self.isValidTag(tag) else {
                        Current.Log
                            .error(
                                "HandlerStartOrUpdateLiveActivity: invalid tag '\(tag)' — must be [a-zA-Z0-9_-], max 64 chars"
                            )
                        throw ValidationError.invalidTag
                    }

                    guard let title = payload["title"] as? String, !title.isEmpty else {
                        throw ValidationError.missingTitle
                    }

                    Self.showPrivacyDisclosureIfNeeded()

                    let state = Self.contentState(from: payload)

                    try await Current.liveActivityRegistry.startOrUpdate(
                        tag: tag,
                        title: title,
                        state: state
                    )
                    seal.fulfill(())
                } catch {
                    Current.Log.error("HandlerStartOrUpdateLiveActivity: \(error)")
                    // Fulfill rather than reject for known validation/auth errors so HA
                    // doesn't treat them as transient failures and retry indefinitely.
                    switch error {
                    case ValidationError.missingTag, ValidationError.missingTitle, ValidationError.invalidTag:
                        seal.fulfill(())
                    default:
                        seal.reject(error)
                    }
                }
            }
        }
    }

    // MARK: - Privacy Disclosure

    /// Records that the user has started a Live Activity so that the Settings screen
    /// can surface the privacy notice on their next visit.
    /// The permanent disclosure lives in LiveActivitySettingsView's privacy section —
    /// a local notification would silently fail if notification permission is not granted.
    private static func showPrivacyDisclosureIfNeeded() {
        guard !Current.settingsStore.hasSeenLiveActivityDisclosure else { return }
        Current.settingsStore.hasSeenLiveActivityDisclosure = true
    }

    // MARK: - Validation

    /// Validates that a Live Activity tag contains only safe characters.
    ///
    /// Tags are used as ActivityKit push token topic identifiers and as keys in
    /// the activity registry dictionary. Restricting to `[a-zA-Z0-9_-]` (max 64
    /// characters) ensures they are safe for APNs payloads, UserDefaults keys,
    /// and log output without escaping or truncation issues.
    static func isValidTag(_ tag: String) -> Bool {
        guard tag.count <= 64 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Payload Parsing

    static func contentState(from payload: [String: Any]) -> HALiveActivityAttributes.ContentState {
        let message = payload["message"] as? String ?? ""
        let criticalText = payload["critical_text"] as? String
        // Use NSNumber coercion so both Int and Double JSON values (e.g. 50 vs 50.0) decode correctly.
        let progress = (payload["progress"] as? NSNumber).map { Int(truncating: $0) }
        let progressMax = (payload["progress_max"] as? NSNumber).map { Int(truncating: $0) }
        let chronometer = payload["chronometer"] as? Bool
        let icon = payload["notification_icon"] as? String
        let color = payload["notification_icon_color"] as? String

        // `when` + `when_relative` → absolute countdown end date.
        // Parsed as Double to preserve sub-second Unix timestamps sent by HA.
        var countdownEnd: Date?
        if let when = (payload["when"] as? NSNumber).map(\.doubleValue) {
            let whenRelative = payload["when_relative"] as? Bool ?? false
            if whenRelative {
                countdownEnd = Date().addingTimeInterval(when)
            } else {
                countdownEnd = Date(timeIntervalSince1970: when)
            }
        }

        return HALiveActivityAttributes.ContentState(
            message: message,
            criticalText: criticalText,
            progress: progress,
            progressMax: progressMax,
            chronometer: chronometer,
            countdownEnd: countdownEnd,
            icon: icon,
            color: color
        )
    }
}

// MARK: - HandlerEndLiveActivity

/// Handles explicit `end_live_activity` commands.
/// Note: the `clear_notification` + `tag` dismiss flow is handled in `HandlerClearNotification`.
@available(iOS 16.2, *)
struct HandlerEndLiveActivity: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard !Current.isAppExtension else {
            return .value(())
        }

        return Promise { seal in
            Task {
                guard let tag = payload["tag"] as? String, !tag.isEmpty,
                      HandlerStartOrUpdateLiveActivity.isValidTag(tag) else {
                    seal.fulfill(())
                    return
                }

                let policy = Self.dismissalPolicy(from: payload)
                await Current.liveActivityRegistry.end(tag: tag, dismissalPolicy: policy)
                seal.fulfill(())
            }
        }
    }

    private static func dismissalPolicy(from payload: [String: Any]) -> ActivityUIDismissalPolicy {
        switch payload["dismissal_policy"] as? String {
        case "default":
            return .default
        case let str where str?.hasPrefix("after:") == true:
            if let timestampStr = str?.dropFirst(6),
               let timestamp = Double(timestampStr) {
                // Cap to 24 hours — iOS enforces its own maximum, but this prevents
                // a far-future date from lingering in the dismissed activities list
                // longer than intended if Apple ever relaxes the OS limit.
                let maxDate = Date().addingTimeInterval(24 * 60 * 60)
                return .after(min(Date(timeIntervalSince1970: timestamp), maxDate))
            }
            return .immediate
        default:
            return .immediate
        }
    }
}
#endif
