import Foundation

public enum AppTriggerSource: String, CaseIterable, CustomStringConvertible {
    case Watch = "watch"
    case Widget = "widget"
    case AppShortcut = "appShortcut" // UIApplicationShortcutItem
    case Preview = "preview"
    case SiriShortcut = "siriShortcut"
    case URLHandler = "urlHandler"
    case CarPlay = "carPlay"
    case AppIntent = "appIntent"

    public var description: String {
        rawValue
    }
}
