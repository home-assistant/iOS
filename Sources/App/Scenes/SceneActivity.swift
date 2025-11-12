import UIKit

enum SceneActivity: CaseIterable {
    case webView
    case settings
    case about
    case carPlay
    case assist

    init(activityIdentifier: String) {
        self = Self.allCases.first(where: { $0.activityIdentifier == activityIdentifier }) ?? .webView
    }

    init(configurationName: String) {
        self = Self.allCases.first(where: { $0.configurationName == configurationName }) ?? .webView
    }

    var activity: NSUserActivity {
        .init(activityType: activityIdentifier)
    }

    func activity(with userInfo: [AnyHashable: Any]) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityIdentifier)
        activity.userInfo = userInfo
        return activity
    }

    var activityIdentifier: String {
        switch self {
        case .settings: return "ha.settings"
        case .webView: return "ha.webview"
        case .about: return "ha.about"
        case .carPlay: return "ha.carPlay"
        case .assist: return "ha.assist"
        }
    }

    var configurationName: String {
        switch self {
        case .webView: return "WebView"
        case .settings: return "Settings"
        case .about: return "About"
        case .carPlay: return "CarPlay"
        case .assist: return "Assist"
        }
    }

    var configuration: UISceneConfiguration {
        switch self {
        case .webView, .settings, .about, .assist: return .init(
                name: configurationName,
                sessionRole: .windowApplication
            )
        case .carPlay: return .init(name: configurationName, sessionRole: .carTemplateApplication)
        }
    }
}
