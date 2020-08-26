import UIKit

@available(iOS 13, *)
enum SceneActivity: CaseIterable {
    case webView
    case settings
    case about

    init(activityIdentifier: String) {
        self = Self.allCases.first(where: { $0.activityIdentifier == activityIdentifier }) ?? .webView
    }

    init(configurationName: String) {
        self = Self.allCases.first(where: { $0.configurationName == configurationName }) ?? .webView
    }

    var activity: NSUserActivity {
        .init(activityType: activityIdentifier)
    }

    var activityIdentifier: String {
        switch self {
        case .settings: return "ha.settings"
        case .webView: return "ha.webview"
        case .about: return "ha.about"
        }
    }

    var configurationName: String {
        switch self {
        case .webView: return "WebView"
        case .settings: return "Settings"
        case .about: return "About"
        }
    }

    var configuration: UISceneConfiguration {
        .init(name: configurationName, sessionRole: .windowApplication)
    }
}
