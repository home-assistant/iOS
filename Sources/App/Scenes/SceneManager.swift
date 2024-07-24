import Foundation
import MBProgressHUD
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

    var webViewWindowControllerPromise: Guarantee<WebViewWindowController> {
        firstly { () -> Guarantee<WebViewSceneDelegate> in
            scene(for: .init(activity: .webView))
        }.map { delegate in
            delegate.windowController!
        }
    }

    init() {
        Current.realmFatalPresentation = { [weak self] viewController in
            guard let self else { return }

            let under = UIViewController()
            under.view.backgroundColor = .black
            under.modalPresentationStyle = .fullScreen

            webViewWindowControllerPromise.done { parent in
                parent.present(under, animated: false, completion: {
                    under.present(viewController, animated: true, completion: nil)
                })
            }
        }
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
            scene.session.configuration.name.flatMap(SceneActivity.init(configurationName:)) == activity
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
    }

    public func scene<DelegateType: UIWindowSceneDelegate>(
        for query: SceneQuery<DelegateType>
    ) -> Guarantee<DelegateType> {
        if let active = existingScenes(for: query.activity).first,
           let delegate = active.delegate as? DelegateType {
            let options = UIScene.ActivationRequestOptions()
            options.requestingScene = active

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
            let hud = MBProgressHUD.showAdded(to: window, animated: true)
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
