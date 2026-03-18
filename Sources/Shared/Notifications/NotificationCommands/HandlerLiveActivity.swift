#if canImport(ActivityKit)
import ActivityKit
import Foundation
import PromiseKit
import UserNotifications

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
@available(iOS 16.1, *)
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
                        Current.Log.error("HandlerStartOrUpdateLiveActivity: invalid tag '\(tag)' — must be [a-zA-Z0-9_-], max 64 chars")
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

    /// Shows a one-time local notification reminding the user that Live Activity
    /// content is visible on the Lock Screen without authentication.
    /// Runs at most once per device; subsequent calls are no-ops.
    private static func showPrivacyDisclosureIfNeeded() {
        guard !Current.settingsStore.hasSeenLiveActivityDisclosure else { return }
        Current.settingsStore.hasSeenLiveActivityDisclosure = true

        let content = UNMutableNotificationContent()
        content.title = "Live Activity Privacy"
        content.body = "Live Activity content is visible on your Lock Screen and Dynamic Island without Face ID or Touch ID. Choose what you display carefully."

        let request = UNNotificationRequest(
            identifier: "live_activity_privacy_disclosure",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log.error("HandlerStartOrUpdateLiveActivity: failed to post privacy disclosure: \(error)")
            }
        }
    }

    // MARK: - Validation

    /// Tag must be alphanumeric with hyphens/underscores, max 64 characters.
    /// Matches the safe subset of APNs collapse identifiers.
    private static func isValidTag(_ tag: String) -> Bool {
        guard tag.count <= 64 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Payload Parsing

    static func contentState(from payload: [String: Any]) -> HALiveActivityAttributes.ContentState {
        let message = payload["message"] as? String ?? ""
        let criticalText = payload["critical_text"] as? String
        let progress = payload["progress"] as? Int
        let progressMax = payload["progress_max"] as? Int
        let chronometer = payload["chronometer"] as? Bool
        let icon = payload["notification_icon"] as? String
        let color = payload["notification_icon_color"] as? String

        // `when` + `when_relative` → absolute countdown end date
        var countdownEnd: Date?
        if let when = payload["when"] as? Int {
            let whenRelative = payload["when_relative"] as? Bool ?? false
            if whenRelative {
                countdownEnd = Date().addingTimeInterval(Double(when))
            } else {
                countdownEnd = Date(timeIntervalSince1970: Double(when))
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
@available(iOS 16.1, *)
struct HandlerEndLiveActivity: NotificationCommandHandler {
    func handle(_ payload: [String: Any]) -> Promise<Void> {
        guard !Current.isAppExtension else {
            return .value(())
        }

        return Promise { seal in
            Task {
                guard let tag = payload["tag"] as? String, !tag.isEmpty else {
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
                return .after(Date(timeIntervalSince1970: timestamp))
            }
            return .immediate
        default:
            return .immediate
        }
    }
}
#endif
