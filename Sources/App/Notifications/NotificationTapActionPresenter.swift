import PromiseKit
import Shared
import UIKit
import UserNotifications

/// Offers a notification's actions when the user taps it rather than pressing and holding to reveal them.
///
/// iOS only shows notification actions once the notification is expanded, which is enough of a secret that
/// a tap on an actionable notification usually lands on nothing at all: the actions the automation defined
/// are there, they were just never seen. When a plain tap has nothing else to do, the same actions are
/// offered in an alert, and picking one runs it exactly as the system would have.
///
/// Off until the user turns it on in Settings › Notifications (`SettingsStore.notificationTapActionsEnabled`),
/// since it changes what tapping a notification does.
///
/// Whatever the payload already asks a tap to do wins. A `url` to open and an `entity_id` to show are
/// routed by `NotificationManager` before a tap reaches this; a shortcut to run and a command to send are
/// checked for here — see `tapRunsSomethingElse(for:)`.
final class NotificationTapActionPresenter {
    /// The actions a plain tap should offer: the ones the payload carries, or — for a notification that
    /// names a category instead — the ones that category was configured with. Snooze presets are
    /// deliberately left out, because they are a convenience of ours that the system adds when a
    /// notification brings no actions of its own, not something the notification asked for.
    static func actions(for content: UNNotificationContent, server: Server) -> [NotificationAction] {
        let payloadActions = content.userInfoPayloadActions

        guard payloadActions.isEmpty else {
            return offerable(payloadActions)
        }

        let categoryIdentifier = content.categoryIdentifier.lowercased()

        guard !categoryIdentifier.isEmpty else {
            return []
        }

        // A category is stored under its identifier alone, so the row on file can belong to another
        // server, whose actions would then be fired against the server this notification came from.
        // A category made on the device carries no server of its own and belongs to all of them.
        let category = NotificationCategory.all().first {
            $0.identifier.lowercased() == categoryIdentifier
                && ($0.serverIdentifier.isEmpty || $0.serverIdentifier == server.identifier.rawValue)
        }

        return offerable(category?.actions ?? [])
    }

    /// The actions the app may run itself. One that requires authentication is left to the system,
    /// which is the same call `NotificationActionSplit` makes for the watch: the app cannot reproduce
    /// the unlock gate `UNNotificationAction` applies, and quietly dropping that requirement is worse
    /// than the action only being reachable by pressing and holding the notification.
    private static func offerable(_ actions: [NotificationAction]) -> [NotificationAction] {
        actions.filter { !$0.authenticationRequired }
    }

    /// Whether the payload asks a tap to do something of its own, which the actions alert must not take
    /// the place of. A `url` to open and an `entity_id` to show are routed by `NotificationManager` before
    /// a tap reaches here, so what is left to look for is the shortcut it runs and the command it sends.
    static func tapRunsSomethingElse(for content: UNNotificationContent) -> Bool {
        let userInfo = content.userInfo

        if let shortcut = userInfo["shortcut"] as? [String: String], shortcut["name"] != nil {
            return true
        }

        if let haDict = userInfo["homeassistant"] as? [String: Any],
           (haDict["command"] as? String) != nil || (haDict["live_update"] as? Bool) == true {
            return true
        }

        return false
    }

    /// Offers `content`'s actions, unless the user has not asked for this, the tap is already spoken
    /// for, or the notification has no actions. Returns whether anything was offered.
    @discardableResult
    func present(for content: UNNotificationContent, server: Server) -> Bool {
        guard Current.settingsStore.notificationTapActionsEnabled else {
            return false
        }

        guard !Self.tapRunsSomethingElse(for: content) else {
            return false
        }

        let actions = Self.actions(for: content, server: server)

        guard !actions.isEmpty else {
            return false
        }

        Current.Log.info("offering \(actions.count) action(s) from a notification tap")
        present(makeAlert(for: actions, content: content, server: server))
        return true
    }

    /// The alert listing `actions`, headed by the notification itself so it stays obvious which one is
    /// being acted on.
    func makeAlert(
        for actions: [NotificationAction],
        content: UNNotificationContent,
        server: Server
    ) -> UIAlertController {
        let alert = UIAlertController(
            title: content.title.isEmpty ? L10n.NotificationTapActions.title : content.title,
            message: content.body.isEmpty ? nil : content.body,
            preferredStyle: .alert
        )

        for action in actions {
            alert.addAction(UIAlertAction(
                title: action.title,
                style: action.destructive ? .destructive : .default,
                handler: { [weak self] _ in
                    self?.select(action, content: content, server: server)
                }
            ))
        }

        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))

        return alert
    }

    /// A text-input action needs to know what to send before it can run, so it gets a second alert to
    /// type into; everything else runs straight away.
    func select(_ action: NotificationAction, content: UNNotificationContent, server: Server) {
        guard action.textInput else {
            perform(action, content: content, server: server, textInput: nil)
            return
        }

        present(makeTextInputAlert(for: action, content: content, server: server))
    }

    /// The reply alert for a text-input action, matching the keyboard the system would have shown above
    /// the notification: the action's own placeholder and send button.
    func makeTextInputAlert(
        for action: NotificationAction,
        content: UNNotificationContent,
        server: Server
    ) -> UIAlertController {
        let alert = UIAlertController(title: action.title, message: nil, preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = action.textInputPlaceholder
        }

        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: action.textInputButtonTitle,
            style: .default,
            handler: { [weak self, weak alert] _ in
                self?.send(action, content: content, server: server, from: alert)
            }
        ))

        return alert
    }

    /// Runs `action` with whatever was typed into `alert`. An empty reply is still a reply — the
    /// system's own response path forwards it (`UNTextInputNotificationResponse.userText` is
    /// non-optional), so swallowing it here would lose an event the user asked to send.
    func send(
        _ action: NotificationAction,
        content: UNNotificationContent,
        server: Server,
        from alert: UIAlertController?
    ) {
        perform(action, content: content, server: server, textInput: alert?.textFields?.first?.text ?? "")
    }

    /// Runs `action` as if the user had picked it from the notification itself: whatever URL it carries
    /// is opened, and Home Assistant hears which action fired, along with anything typed for it.
    func perform(
        _ action: NotificationAction,
        content: UNNotificationContent,
        server: Server,
        textInput: String?
    ) {
        if let urlString = content.urlString(forActionIdentifier: action.identifier) {
            Current.Log.info("launching URL \(urlString) for notification action \(action.identifier)")
            Current.sceneManager.appCoordinator.done {
                $0.open(from: .notification, server: server, urlString: urlString, isComingFromAppIntent: false)
            }
        }

        let info = HomeAssistantAPI.PushActionInfo(
            content: content,
            actionIdentifier: action.identifier,
            textInput: textInput
        )

        Current.backgroundTask(withName: BackgroundTask.handlePushAction.rawValue) { _ in
            Current.api(for: server)?
                .handlePushAction(for: info) ?? .init(error: HomeAssistantAPI.APIError.noAPIAvailable)
        }.catch { error in
            Current.Log.error("Error when handling a notification action chosen from a tap: \(error)")
        }
    }

    private func present(_ alert: UIAlertController) {
        Current.sceneManager.appCoordinator.done { $0.present(alert) }
    }
}
