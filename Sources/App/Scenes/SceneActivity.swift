import UIKit

enum SceneActivity: CaseIterable {
    case webView
    case settings
    case about
    case carPlay

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
        case .carPlay: return "ha.carPlay"
        }
    }

    var configurationName: String {
        switch self {
        case .webView: return "WebView"
        case .settings: return "Settings"
        case .about: return "About"
        case .carPlay: return "CarPlay"
        }
    }

    var configuration: UISceneConfiguration {
        switch self {
        case .webView, .settings, .about: return .init(name: configurationName, sessionRole: .windowApplication)
        case .carPlay: return .init(name: configurationName, sessionRole: .carTemplateApplication)
        }
    }
}
