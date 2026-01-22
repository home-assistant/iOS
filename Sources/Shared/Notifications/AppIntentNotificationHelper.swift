#if canImport(ActivityKit)
import ActivityKit
#endif
import Foundation

public enum AppIntentNotificationHelper {
    /// Shows a confirmation message for an AppIntent execution
    /// - On iOS 16.2+: Displays as a Live Activity in the Dynamic Island
    /// - On iOS < 16.2: Falls back to local notification
    public static func showConfirmation(
        id: NotificationIdentifier,
        title: String,
        body: String? = nil,
        isSuccess: Bool,
        duration: TimeInterval = 3.0
    ) {
        #if canImport(ActivityKit)
        if #available(iOS 16.2, *) {
            showLiveActivity(id: id, title: title, isSuccess: isSuccess, duration: duration)
        } else {
            showNotification(id: id, title: title, body: body)
        }
        #else
        showNotification(id: id, title: title, body: body)
        #endif
    }

    #if canImport(ActivityKit)
    @available(iOS 16.2, *)
    private static func showLiveActivity(
        id: NotificationIdentifier,
        title: String,
        isSuccess: Bool,
        duration: TimeInterval
    ) {
        let attributes = AppIntentConfirmationAttributes(id: id.rawValue)
        let contentState = AppIntentConfirmationAttributes.ContentState(
            title: title,
            isSuccess: isSuccess
        )

        do {
            // Request the Live Activity
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )

            // Schedule auto-dismiss after duration
            Task {
                try? await Task.sleep(for: .seconds(duration))
                await endLiveActivity(activity)
            }
        } catch {
            // If Live Activity fails, fall back to notification
            Current.Log.error("Failed to start Live Activity for AppIntent confirmation: \(error)")
            showNotification(id: id, title: title, body: nil)
        }
    }

    @available(iOS 16.2, *)
    private static func endLiveActivity(_ activity: Activity<AppIntentConfirmationAttributes>) async {
        let contentState = activity.content.state
        await activity.end(
            .init(state: contentState, staleDate: nil),
            dismissalPolicy: .immediate
        )
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
