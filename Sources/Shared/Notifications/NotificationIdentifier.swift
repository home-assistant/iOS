import Foundation

public enum NotificationIdentifier: String {
    case automationAppIntentRun
    case scriptAppIntentRun
    case sceneAppIntentRun
    case carPlayIntro
    case intentToggleFailed
    case intentActivateFailed
    case intentPressFailed
    case serverUnreachable

    // Debug
    case debug
}
