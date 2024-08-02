import Foundation

public enum NotificationIdentifier: String {
    case carPlayActionIntro = "CarPlay-action-intro"
    case improvSetup = "Improv-Setup"

    #if DEBUG
    case debug
    #endif
}
