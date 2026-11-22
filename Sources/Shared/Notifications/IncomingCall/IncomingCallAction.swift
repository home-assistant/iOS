import Foundation

/// What happened to an incoming call, sent back to Home Assistant as a `mobile_app_notification_action` event.
///
/// The same identifiers name the Answer and Decline actions of the notification shown when a call does not ring
/// through CallKit, so an automation handles both the same way, reading the call from `action_data.tag`.
public enum IncomingCallAction: String, CaseIterable {
    /// The call was answered.
    case answer = "CALL_ANSWER"
    /// The call was declined.
    case decline = "CALL_DECLINE"
    /// Nobody answered before the timeout.
    case missed = "CALL_MISSED"
    /// Another call was already ringing or in progress.
    case busy = "CALL_BUSY"
}
