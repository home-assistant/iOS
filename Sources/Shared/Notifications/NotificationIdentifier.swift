import Foundation

public enum NotificationIdentifier: String {
    case automationAppIntentRun
    case scriptAppIntentRun
    case sceneAppIntentRun
    case intentToggleFailed
    case intentActivateFailed
    case intentPressFailed
    case serverUnreachable
    case forceQuit

    // Debug
    case debug
}
