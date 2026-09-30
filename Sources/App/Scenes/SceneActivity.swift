#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum SceneActivity: CaseIterable {
    case webView
    case settings
    case about
    case carPlay
    case assist
    case onboarding

    init(activityIdentifier: String) {
        self = Self.allCases.first(where: { $0.activityIdentifier == activityIdentifier }) ?? .webView
    }

    init(configurationName: String) {
        self = Self.allCases.first(where: { $0.configurationName == configurationName }) ?? .webView
    }

    var activity: NSUserActivity {
        let activity = NSUserActivity(activityType: activityIdentifier)
        // `targetContentIdentifier` is what SwiftUI `handlesExternalEvents(matching:)` matches against, so
        // scenes activated for this activity route to the right `WindowGroup` (e.g. Settings) in `HAApp`.
        activity.targetContentIdentifier = activityIdentifier
        return activity
    }

    func activity(with userInfo: [AnyHashable: Any]) -> NSUserActivity {
        let activity = NSUserActivity(activityType: activityIdentifier)
        activity.targetContentIdentifier = activityIdentifier
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
        case .onboarding: return "ha.onboarding"
        }
    }

    var configurationName: String {
        switch self {
        case .webView: return "WebView"
        case .settings: return "Settings"
        case .about: return "About"
        case .carPlay: return "CarPlay"
        case .assist: return "Assist"
        case .onboarding: return "Onboarding"
        }
    }

    #if os(iOS)
    var configuration: UISceneConfiguration {
        switch self {
        case .webView, .settings, .about, .assist, .onboarding:
            let configuration = UISceneConfiguration(name: configurationName, sessionRole: .windowApplication)
            configuration.delegateClass = sceneDelegateClass
            return configuration
        case .carPlay: return .init(name: configurationName, sessionRole: .carTemplateApplication)
        }
    }
    #endif

    /// The size a window of this kind opens at before the user has ever placed it. `nil` leaves the window to
    /// macOS, which opens it at the frontmost window's frame.
    var defaultMacWindowSize: CGSize? {
        switch self {
        case .assist: return .init(width: 400, height: 600)
        case .webView, .settings, .about, .carPlay, .onboarding: return nil
        }
    }

    #if os(macOS)
    /// The size a window of this kind opens at in the native Mac app before the user has ever placed it. A
    /// SwiftUI window otherwise opens at the smallest size its content accepts.
    var initialWindowSize: CGSize {
        switch self {
        case .webView, .carPlay: return .init(width: 1100, height: 760)
        case .settings: return .init(width: 960, height: 680)
        case .about: return .init(width: 480, height: 680)
        case .assist: return defaultMacWindowSize ?? .init(width: 400, height: 600)
        case .onboarding: return .init(width: 560, height: 720)
        }
    }

    /// The smallest size a window of this kind can be resized to in the native Mac app: what the onboarding
    /// screens shown in the main window need to lay out without overlapping.
    var minimumWindowSize: CGSize {
        .init(width: 480, height: 600)
    }
    #endif

    /// Windows that remember their geometry need a scene delegate to receive the lifecycle callbacks
    /// `WindowScenesManager` acts on. The main window's delegate is attached in `AppDelegate` instead, since it
    /// also carries quick-action and browser-launch behaviour.
    #if os(iOS)
    private var sceneDelegateClass: AnyClass? {
        switch self {
        case .assist: return AssistWindowSceneDelegate.self
        case .webView, .settings, .about, .carPlay, .onboarding: return nil
        }
    }
    #endif
}
