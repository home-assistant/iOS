import Foundation

/// How a notification's payload actions divide between the system and the app itself.
///
/// The watch long look needs this: watchOS never hands a `UNTextInputNotificationResponse` back to
/// the app for a notification forwarded from the paired iPhone, so a text-input action left to the
/// system shows its reply screen and then drops whatever was typed. Those actions are presented by
/// the app instead.
///
/// An action that requires authentication stays with the system even when it takes text: the app
/// cannot reproduce the `.authenticationRequired` gate `UNNotificationAction` applies, and quietly
/// dropping that requirement is worse than the reply not going through.
public struct NotificationActionSplit: Equatable {
    /// Actions left to the system, in payload order.
    public let systemHandled: [NotificationAction]
    /// Actions the app presents and fires itself, in payload order.
    public let appHandled: [NotificationAction]

    public init(payloadActions: [NotificationAction]) {
        self.appHandled = payloadActions.filter { $0.textInput && !$0.authenticationRequired }
        self.systemHandled = payloadActions.filter { !$0.textInput || $0.authenticationRequired }
    }
}
