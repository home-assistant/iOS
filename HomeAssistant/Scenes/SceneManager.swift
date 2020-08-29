import Foundation
import UIKit
import PromiseKit
import Shared

// todo: can i combine this with the enum?
@available(iOS 13, *)
struct SceneQuery<DelegateType: UIWindowSceneDelegate> {
    let activity: SceneActivity
}

@available(iOS 13, *)
extension UIWindowSceneDelegate {
    func informManager(from connectionOptions: UIScene.ConnectionOptions) {
        let pendingResolver: (Self) -> Void = UIApplication.shared.typedDelegate.sceneManager
            .pendingResolver(from: connectionOptions.userActivities)

        pendingResolver(self)
    }
}

@available(iOS, deprecated: 13.0)
struct SceneManagerPreSceneCompatibility {
    var windowController: WebViewWindowController?
    var urlHandler: IncomingURLHandler?
    let windowControllerPromise: Guarantee<WebViewWindowController>
    let windowControllerSeal: (WebViewWindowController) -> Void

    init() {
        (self.windowControllerPromise, self.windowControllerSeal) = Guarantee<WebViewWindowController>.pending()
    }

    mutating func start() {
        let window = UIWindow(haForiOS12: ())
        let windowController = WebViewWindowController(window: window, restorationActivity: nil)
        self.windowController = windowController
        self.urlHandler = IncomingURLHandler(windowController: windowController)
        windowControllerSeal(windowController)
    }

    func setup() {
        windowControllerPromise.done { $0.setup() }
    }
}

class SceneManager {
    // types too hard here
    fileprivate static var activityUserInfoKeyResolver = "resolver"
    private var pendingResolvers: [String: Any] = [:]

    @available(iOS, deprecated: 13.0)
    var compatibility = SceneManagerPreSceneCompatibility()

    var webViewWindowControllerPromise: Guarantee<WebViewWindowController> {
        if #available(iOS 13, *) {
            return firstly { () -> Guarantee<WebViewSceneDelegate> in
                scene(for: .init(activity: .webView))
            }.map { delegate in
                delegate.windowController!
            }
        } else {
            return compatibility.windowControllerPromise
        }
    }

    fileprivate func pendingResolver<T>(from activities: Set<NSUserActivity>) -> (T) -> Void {
        let (promise, outerResolver) = Guarantee<T>.pending()

        activities.compactMap { activity in
            activity.userInfo?[Self.activityUserInfoKeyResolver] as? String
        }.compactMap { token in
            pendingResolvers[token] as? (T) -> Void
        }.forEach { resolver in
            promise.done { resolver($0) }
        }

        return outerResolver
    }

    @available(iOS 13, *)
    private func existingScenes(for activity: SceneActivity) -> [UIScene] {
        UIApplication.shared.connectedScenes.filter { scene in
            scene.session.configuration.name.flatMap(SceneActivity.init(configurationName:)) == activity
        }.filter {
            $0.activationState != .unattached
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

    @available(iOS 13, *)
    public func activateAnyScene(for activity: SceneActivity) {
        UIApplication.shared.requestSceneSessionActivation(
            existingScenes(for: activity).first?.session,
            userActivity: activity.activity,
            options: nil
        ) { error in
            Current.Log.error(error)
        }
    }

    @available(iOS 13, *)
    public func scene<DelegateType: UIWindowSceneDelegate>(
        for query: SceneQuery<DelegateType>
    ) -> Guarantee<DelegateType> {
        if let active = existingScenes(for: query.activity).first,
           let delegate = active.delegate as? DelegateType {
            UIApplication.shared.requestSceneSessionActivation(
                active.session,
                userActivity: nil,
                options: nil,
                errorHandler: nil
            )
            return .value(delegate)
        }

        let (promise, resolver) = Guarantee<DelegateType>.pending()

        let token = UUID().uuidString
        pendingResolvers[token] = resolver

        let activity = query.activity.activity
        activity.userInfo = [
            Self.activityUserInfoKeyResolver: token
        ]

        UIApplication.shared.requestSceneSessionActivation(
            nil,
            userActivity: activity,
            options: nil,
            errorHandler: { error in
                // error is called in most cases, even when no error occurs, so we silently swallow it
                // todo: does this actually happen in normal circumstances?
                Current.Log.error("scene activation error: \(error)")
            }
        )

        return promise
    }
}
