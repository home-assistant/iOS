import Foundation

public enum NotificationIdentifier: String {
    case automationAppIntentRun
    case scriptAppIntentRun
    case sceneAppIntentRun
    case intentToggleFailed
    case intentActivateFailed
    case intentPressFailed
    case intentPerformActionFailed
    case serverUnreachable
    case liveActivityTokenUnreachable

    // Debug
    case debug
}
