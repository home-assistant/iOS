#if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && os(iOS)
import ActivityKit
#endif
import AppIntents
import Foundation

public enum AppIntentNotificationHelper {
    /// Shows a confirmation message for an AppIntent execution
    /// - On iOS 16.2+: Displays as a Live Activity in the Dynamic Island via LiveActivityIntent
    /// - On iOS < 16.2: Falls back to local notification
    public static func showConfirmation(
        id: NotificationIdentifier,
        title: String,
        body: String? = nil,
        isSuccess: Bool,
        duration: TimeInterval = 3.0
    ) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && os(iOS)
        if #available(iOS 16.2, *) {
            showLiveActivity(id: id, title: title, isSuccess: isSuccess, duration: duration)
        } else {
            showNotification(id: id, title: title, body: body)
        }
        #else
        showNotification(id: id, title: title, body: body)
        #endif
    }

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst) && os(iOS)
    @available(iOS 16.2, *)
    private static func showLiveActivity(
        id: NotificationIdentifier,
        title: String,
        isSuccess: Bool,
        duration: TimeInterval
    ) {
        // By conforming to LiveActivityIntent, the ShowConfirmationAppIntent
        // will be executed by the system in the main app process, even when
        // invoked from a widget extension. This allows Live Activities to work
        // from widgets without the "unsupportedTarget" error.

        Task {
            do {
                // Create and invoke the LiveActivityIntent
                // The system will automatically run this in the main app process
                let intent = ShowConfirmationAppIntent(
                    identifier: id.rawValue,
                    title: title,
                    isSuccess: isSuccess,
                    duration: duration
                )

                _ = try await intent.perform()
                Current.Log.info("Successfully invoked Live Activity intent for: \(id.rawValue)")
            } catch {
                // If Live Activity fails for any reason, fall back to notification
                Current.Log.error("Failed to start Live Activity: \(error.localizedDescription)")
                showNotification(id: id, title: title, body: nil)
            }
        }
    }

    #endif

    private static func showNotification(
        id: NotificationIdentifier,
        title: String,
        body: String?
    ) {
        Current.notificationDispatcher.send(.init(
            id: id,
            title: title,
            body: body
        ))
    }
}
