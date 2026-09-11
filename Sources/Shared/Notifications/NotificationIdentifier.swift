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

    // Beacon diagnostics
    case beaconDetectedLocally
    case beaconExitedLocally
    case beaconEventPreflightFailed
    case beaconEventPersisted
    case beaconEventUploadStarted
    case beaconEventUploadStalled
    case beaconEventDelivered
    case beaconEventQueued

    // Debug
    case debug
}
