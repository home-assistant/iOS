import Foundation
import PromiseKit
import Shared
import UIKit

// TODO: can i combine this with the enum?

struct SceneQuery<DelegateType: UIWindowSceneDelegate> {
    let activity: SceneActivity
}

extension UIWindowSceneDelegate {
    func informManager(from connectionOptions: UIScene.ConnectionOptions) {
        let pendingResolver: (Self) -> Void = Current.sceneManager
            .pendingResolver(from: connectionOptions.userActivities)

        pendingResolver(self)
    }
}

/// The app-level coordinator for the primary web-view window. Implemented by `HomeAssistantView`'s
/// coordinator as the web view migrates off `WebViewWindowController`; reached via `SceneManager.appCoordinator`.
///
/// Not `@MainActor` — like the `WebViewWindowController` it replaces, it's called from PromiseKit `.done`
/// closures (which run on the main queue) across non-isolated contexts.
/// Where a URL-open request originated, used for the confirmation prompt copy.
enum OpenSource {
    case notification
    case deeplink

    func message(with urlString: String) -> String {
        switch self {
        case .notification: return L10n.Alerts.OpenUrlFromNotification.message(urlString)
        case .deeplink: return L10n.Alerts.OpenUrlFromDeepLink.message(urlString)
        }
    }
}

protocol AppCoordinator: AnyObject {
    var presentedViewController: UIViewController? { get }
    var window: UIWindow? { get }
    func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?)
    func show(alert: ServerAlert)
    func showSettings()
    func showAssistSettings()
    func showDownloadManager(_ viewModel: DownloadManagerViewModel)
    func showOnboardingPermissions(server: Server, steps: [OnboardingPermissionsNavigationViewModel.StepID])
    @discardableResult func open(server: Server) -> Guarantee<any WebFrontend>
    func selectServer(prompt: String?, includeSettings: Bool, completion: @escaping (Server) -> Void)
    func presentInvitation(url: URL?)
    func setup()
    func open(
        from: OpenSource,
        server: Server,
        urlString: String,
        skipConfirm: Bool,
        avoidUnnecessaryReload: Bool,
        isComingFromAppIntent: Bool
    )
    func openSelectingServer(
        from: OpenSource,
        urlString: String,
        skipConfirm: Bool,
        queryParameters: [URLQueryItem]?,
        isComingFromAppIntent: Bool
    )
}

extension AppCoordinator {
    func present(_ viewController: UIViewController) {
        present(viewController, animated: true, completion: nil)
    }

    /// Convenience matching the old default arguments (`skipConfirm`/`avoidUnnecessaryReload` = false).
    func open(from: OpenSource, server: Server, urlString: String, isComingFromAppIntent: Bool) {
        open(
            from: from,
            server: server,
            urlString: urlString,
            skipConfirm: false,
            avoidUnnecessaryReload: false,
            isComingFromAppIntent: isComingFromAppIntent
        )
    }

    /// Convenience with default `avoidUnnecessaryReload` = false.
    func open(from: OpenSource, server: Server, urlString: String, skipConfirm: Bool, isComingFromAppIntent: Bool) {
        open(
            from: from,
            server: server,
            urlString: urlString,
            skipConfirm: skipConfirm,
            avoidUnnecessaryReload: false,
            isComingFromAppIntent: isComingFromAppIntent
        )
    }

    /// Convenience with default `queryParameters` = nil.
    func openSelectingServer(from: OpenSource, urlString: String, skipConfirm: Bool, isComingFromAppIntent: Bool) {
        openSelectingServer(
            from: from,
            urlString: urlString,
            skipConfirm: skipConfirm,
            queryParameters: nil,
            isComingFromAppIntent: isComingFromAppIntent
        )
    }
}

final class SceneManager {
    // types too hard here
    fileprivate static let activityUserInfoKeyResolver = "resolver"

    private struct PendingResolver {
        private var handleBlock: (Any) -> Void
        init<T>(resolver: @escaping (T) -> Void) {
            self.handleBlock = { value in
                if let value = value as? T {
                    resolver(value)
                }
            }
        }

        func resolve(with possible: some Any) {
            handleBlock(possible)
        }
    }

    private var pendingResolvers: [String: PendingResolver] = [:]

    /// The current foreground `WebViewController`, published by `HomeAssistantView` (the SwiftUI web-frontend
    /// host) as the web view migrates off `WebViewWindowController`. Consumers that only need the web view
    /// read this instead of `webViewWindowControllerPromise.then(\.webViewControllerPromise)`.
    private(set) var webViewControllerPromise: Guarantee<WebViewController>
    private var webViewControllerSeal: (WebViewController) -> Void

    /// Called by `HomeAssistantView` whenever it creates or replaces its `WebViewController`.
    func setWebViewController(_ controller: WebViewController) {
        if webViewControllerPromise.isFulfilled {
            webViewControllerPromise = .value(controller)
        } else {
            webViewControllerSeal(controller)
        }
    }

    private var appCoordinatorPromise: Guarantee<AppCoordinator>
    private var appCoordinatorSeal: (AppCoordinator) -> Void

    /// The primary web-view coordinator (`HomeAssistantView`), replacing `webViewWindowControllerPromise`.
    var appCoordinator: Guarantee<AppCoordinator> { appCoordinatorPromise }

    /// Called by `HomeAssistantView` once its coordinator exists.
    func registerAppCoordinator(_ coordinator: AppCoordinator) {
        if appCoordinatorPromise.isFulfilled {
            appCoordinatorPromise = .value(coordinator)
        } else {
            appCoordinatorSeal(coordinator)
        }
    }

    init() {
        (self.webViewControllerPromise, self.webViewControllerSeal) = Guarantee<WebViewController>.pending()
        (self.appCoordinatorPromise, self.appCoordinatorSeal) = Guarantee<AppCoordinator>.pending()
    }

    fileprivate func pendingResolver<T>(from activities: Set<NSUserActivity>) -> (T) -> Void {
        let (promise, outerResolver) = Guarantee<T>.pending()

        if supportsMultipleScenes {
            activities.compactMap { activity in
                activity.userInfo?[Self.activityUserInfoKeyResolver] as? String
            }.compactMap { token in
                pendingResolvers[token]
            }.forEach { resolver in
                promise.done { resolver.resolve(with: $0) }
            }
        } else {
            pendingResolvers
                .values
                .forEach { resolver in promise.done { resolver.resolve(with: $0) } }
        }

        return outerResolver
    }

    private func existingScenes(for activity: SceneActivity) -> [UIScene] {
        UIApplication.shared.connectedScenes.filter { scene in
            // Filter out scenes that are in the background or unattached state
            // as they may be in the process of being destroyed
            guard scene.activationState != .unattached else {
                return false
            }
            return scene.session.configuration.name.flatMap(SceneActivity.init(configurationName:)) == activity
        }.sorted { a, b in
            switch (a.activationState, b.activationState) {
            case (.unattached, .unattached): return true
            case (.unattached, _): return false
            case (_, .unattached): return true
            case (.foregroundActive, _): return true
            case (_, .foregroundActive): return false
            case (.foregroundInactive, _): return true
            case (_, .foregroundInactive): return false
            case (_, _): return true
            }
        }
    }

    public var supportsMultipleScenes: Bool {
        UIApplication.shared.supportsMultipleScenes
    }

    public func activateAnyScene(for activity: SceneActivity) {
        UIApplication.shared.requestSceneSessionActivation(
            existingScenes(for: activity).first?.session,
            userActivity: activity.activity,
            options: nil
        ) { error in
            Current.Log.error(error)
        }
        bringAppToFrontIfNeeded()
    }

    public func activateAnyScene(for activity: SceneActivity, with userInfo: [AnyHashable: Any]) {
        UIApplication.shared.requestSceneSessionActivation(
            existingScenes(for: activity).first?.session,
            userActivity: activity.activity(with: userInfo),
            options: nil
        ) { error in
            Current.Log.error(error)
        }
        bringAppToFrontIfNeeded()
    }

    private func bringAppToFrontIfNeeded() {
        #if targetEnvironment(macCatalyst)
        Current.macBridge.activateApp()
        #endif
    }

    public func scene<DelegateType: UIWindowSceneDelegate>(
        for query: SceneQuery<DelegateType>
    ) -> Guarantee<DelegateType> {
        if let active = existingScenes(for: query.activity).first,
           let delegate = active.delegate as? DelegateType {
            Current.Log.verbose("Ready to activate scene \(active.session.persistentIdentifier)")

            let options = UIScene.ActivationRequestOptions()
            options.requestingScene = active

            // Only activate scene if not activated already
            guard active.activationState != .foregroundActive else {
                Current.Log
                    .verbose("Did not activate scene \(active.session.persistentIdentifier), it was already active")
                return .value(delegate)
            }

            // Only activate scene if the app is already in foreground or transitioning to foreground
            // This prevents widgets, notifications, or background tasks from unexpectedly bringing the app to
            // foreground
            let shouldActivate = UIApplication.shared.applicationState == .active ||
                active.activationState == .foregroundInactive

            if shouldActivate {
                Current.Log.verbose("Activating scene \(active.session.persistentIdentifier)")

                // Guarantee it runs on main thread when coming from widgets
                DispatchQueue.main.async {
                    if #available(iOS 17.0, *) {
                        UIApplication.shared.activateSceneSession(for: .init(session: active.session, options: options))
                    } else {
                        UIApplication.shared.requestSceneSessionActivation(
                            active.session,
                            userActivity: nil,
                            options: options,
                            errorHandler: nil
                        )
                    }
                }
            } else {
                Current.Log
                    .verbose(
                        "Skipping scene activation for \(active.session.persistentIdentifier) - app is in background"
                    )
            }

            return .value(delegate)
        }

        assert(
            supportsMultipleScenes || query.activity == .webView,
            "if we don't support multiple scenes, how are we running without one besides at immediate startup?"
        )

        let (promise, resolver) = Guarantee<DelegateType>.pending()

        let token = UUID().uuidString
        pendingResolvers[token] = PendingResolver(resolver: resolver)

        if supportsMultipleScenes {
            Current.Log.verbose("Ready to request new scene activation for \(query.activity)")

            let activity = query.activity.activity
            activity.userInfo = [
                Self.activityUserInfoKeyResolver: token,
            ]

            UIApplication.shared.requestSceneSessionActivation(
                nil,
                userActivity: activity,
                options: nil,
                errorHandler: { error in
                    // error is called in most cases, even when no error occurs, so we silently swallow it
                    // TODO: does this actually happen in normal circumstances?
                    Current.Log.error("scene activation error: \(error)")
                }
            )
        }

        return promise
    }

    public func showFullScreenConfirm(
        icon: MaterialDesignIcons,
        text: String,
        onto window: Promise<UIWindow>
    ) {
        window.done { window in
            let hud = ProgressHUD.showAdded(to: window, animated: true)
            hud.mode = .customView
            hud.backgroundView.style = .blur
            hud.customView = with(IconImageView(frame: .init(x: 0, y: 0, width: 64, height: 64))) {
                $0.iconDrawable = icon
            }
            hud.label.text = text
            hud.hide(animated: true, afterDelay: 3)
        }.cauterize()
    }
}
