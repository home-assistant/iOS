import Foundation

public enum NotificationCenterItems {
    // API
    public static let apiDidConnectNotification = Notification.Name(rawValue: "HomeAssistantAPIConnected")

    // Watch
    public static let assistLaunchNotification: Notification.Name = .init("assist-detault-complication-launch")

    // Push notification
    public static let MJPEGStreamerDidReceiveResponse: Notification
        .Name = .init(rawValue: "MJPEGStreamerSessionDelegateDidReceiveResponse")
    public static var notificationCommandManagerDidUpdateComplicationsNotification: Notification.Name {
        .init(rawValue: "didUpdateComplicationsNotification")
    }

    public static let localPushManagerStateDidChange: Notification
        .Name = .init(rawValue: "LocalPushManagerStateDidChange")

    // Location
    public static let locationRelatedSettingDidChange: Notification.Name = .init("locationRelatedSettingDidChange")

    // WebView
    /// These will only be posted on the main thread
    public static let webViewRelatedSettingDidChange: Notification.Name = .init("webViewRelatedSettingDidChange")
    public static let menuRelatedSettingDidChange: Notification.Name = .init("menuRelatedSettingDidChange")

    // Mac
    public static let macScreenSaverDidStart = Notification.Name(rawValue: "com.apple.screensaver.didstart")
    public static let macScreenSaverDidStop = Notification.Name(rawValue: "com.apple.screensaver.didstop")
    public static let macScreenIsLocked = Notification.Name(rawValue: "com.apple.screenIsLocked")
    public static let macScreenIsUnlocked = Notification.Name(rawValue: "com.apple.screenIsUnlocked")
    public static let macWorkspaceWillSleep = Notification.Name(rawValue: "NSWorkspaceWillSleepNotification")
    public static let macWorkspaceDidWake = Notification.Name(rawValue: "NSWorkspaceDidWakeNotification")
    public static let macWorkspaceScreensDidSleep = Notification
        .Name(rawValue: "NSWorkspaceScreensDidSleepNotification")
    public static let macWorkspaceScreensDidWake = Notification.Name(rawValue: "NSWorkspaceScreensDidWakeNotification")
    public static let macWorkspaceSessionDidResignActive = Notification
        .Name(rawValue: "NSWorkspaceSessionDidResignActiveNotification")
    public static let macWorkspaceSessionDidBecomeActive = Notification
        .Name(rawValue: "NSWorkspaceSessionDidBecomeActiveNotification")
    // NonMac_terminationWillBeginNotification
    public static let nonMacTerminationWillBeginNotification = Notification
        .Name(rawValue: "NSApplicationWillTerminateNotification")
}
