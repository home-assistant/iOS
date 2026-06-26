#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation
import PromiseKit

// MARK: - HandlerStartOrUpdateLiveActivity

/// Handles `live_update: true` notifications by starting or updating a Live Activity.
///
/// Triggered two ways:
///   1. `homeassistant.command == "live_activity"` (message: live_activity in YAML)
///   2. `homeassistant.live_update == true` (data.live_update: true in YAML)
///
/// Notification payload fields mirror the Android companion app:
///   tag, title, message, critical_text, progress, progress_max,
///   chronometer, when, when_relative, notification_icon, notification_icon_color
@available(iOS 17.2, *)
struct HandlerStartOrUpdateLiveActivity: NotificationCommandHandler {
    private enum ValidationError: Error {
        case missingTag
        case invalidTag
    }

    func handle(_ payload: [String: Any]) -> Promise<Void> {
        Promise { seal in
            Task {
                do {
                    let request = try Self.makeRequest(from: payload)

                    // Record the disclosure on both start paths. settingsStore is App-Group-backed,
                    // so the extension's write is visible to the app's Settings screen — without this
                    // a Live Activity started via the extension hand-off (drained straight through the
                    // registry, bypassing this handler) would never set the flag.
                    Self.showPrivacyDisclosureIfNeeded()

                    // PushProvider (NEAppPushProvider) runs in a separate OS process — ActivityKit is
                    // unavailable there, and (unlike APNs) a notification delivered over the local-push
                    // channel is never re-delivered to the main app. So instead of dropping the request,
                    // hand it off to the app via the App Group queue + a Darwin signal, mirroring
                    // HandlerClearNotification's end hand-off. The app drains it on the signal and at
                    // launch/foreground. (Darwin can't wake a suspended app, so a local-push start only
                    // materializes when the app is next active; real-time background starts need APNs.)
                    if Current.isAppExtension {
                        Current.Log.verbose(
                            "HandlerStartOrUpdateLiveActivity: handing off start for tag \(request.tag) to the app"
                        )
                        LiveActivityPendingStart.append(request)
                        LiveActivityPendingStart.postDarwinSignal()
                        seal.fulfill(())
                        return
                    }

                    try await Current.liveActivityRegistry?.startOrUpdate(
                        tag: request.tag,
                        title: request.title,
                        serverWebhookId: request.serverWebhookId,
                        state: request.state
                    )
                    seal.fulfill(())
                } catch {
                    Current.Log.error("HandlerStartOrUpdateLiveActivity: \(error)")
                    // Fulfill rather than reject for known validation/auth errors so HA
                    // doesn't treat them as transient failures and retry indefinitely.
                    switch error {
                    case ValidationError.missingTag, ValidationError.invalidTag:
                        seal.fulfill(())
                    default:
                        seal.reject(error)
                    }
                }
            }
        }
    }

    /// Validate and parse a notification payload into a serializable start/update request,
    /// shared by the in-app and extension-handoff paths.
    static func makeRequest(from payload: [String: Any]) throws -> LiveActivityPendingStart.Request {
        guard let tag = payload["tag"] as? String, !tag.isEmpty else {
            throw ValidationError.missingTag
        }
        guard isValidTag(tag) else {
            Current.Log.error(
                "HandlerStartOrUpdateLiveActivity: invalid tag '\(tag)' — must be [a-zA-Z0-9_-], max 64 chars"
            )
            throw ValidationError.invalidTag
        }
        let rawTitle = payload["title"] as? String ?? ""
        let title = rawTitle.isEmpty ? HALiveActivityAttributes.defaultTitle : rawTitle
        return LiveActivityPendingStart.Request(
            tag: tag,
            title: title,
            serverWebhookId: payload["webhook_id"] as? String,
            state: contentState(from: payload)
        )
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
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        return tag.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    // MARK: - Payload Parsing

    static func contentState(from payload: [String: Any]) -> HALiveActivityAttributes.ContentState {
        let title = (payload["title"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let message = payload["message"] as? String ?? ""
        let criticalText = payload["critical_text"] as? String
        // Use NSNumber coercion so both Int and Double JSON values (e.g. 50 vs 50.0) decode correctly.
        let progress = (payload["progress"] as? NSNumber).map { Int(truncating: $0) }
        let progressMax = (payload["progress_max"] as? NSNumber).map { Int(truncating: $0) }
        let chronometer = payload["chronometer"] as? Bool
        let icon = payload["notification_icon"] as? String
        let color = payload["notification_icon_color"] as? String
        let url = payload["url"] as? String
        let backgroundColor = payload["background_color"] as? String
        let textColor = payload["text_color"] as? String
        let progressBarColor = payload["progress_bar_color"] as? String

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
            title: title,
            criticalText: criticalText,
            progress: progress,
            progressMax: progressMax,
            chronometer: chronometer,
            countdownEnd: countdownEnd,
            icon: icon,
            color: color,
            url: url,
            backgroundColor: backgroundColor,
            textColor: textColor,
            progressBarColor: progressBarColor
        )
    }
}

#endif
