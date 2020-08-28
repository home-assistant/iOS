import Foundation
import UIKit
import PromiseKit
import Shared

// todo: can i combine this with the enum?
struct SceneQuery<DelegateType: UIWindowSceneDelegate> {
    let activity: SceneActivity
}

extension UIWindowSceneDelegate {
    func informManager(from connectionOptions: UIScene.ConnectionOptions) {
        let pendingResolver: Resolver<Self> = UIApplication.shared.typedDelegate.sceneManager
            .pendingResolver(from: connectionOptions.userActivities)

        pendingResolver.fulfill(self)
    }
}

class SceneManager {
    // types too hard here
    static var activityUserInfoKeyResolver = "resolver"
    private var pendingResolvers: [String: Any] = [:]

    func pendingResolver<T>(from activities: Set<NSUserActivity>) -> Resolver<T> {
        let (promise, outerResolver) = Promise<T>.pending()

        activities.compactMap { activity in
            activity.userInfo?[Self.activityUserInfoKeyResolver] as? String
        }.compactMap { token in
            pendingResolvers[token] as? Resolver<T>
        }.forEach { resolver in
            promise.pipe(to: { resolver.resolve($0) })
        }

        return outerResolver
    }

    @available(iOS 13, *)
    func existingScenes(for activity: SceneActivity) -> [UIScene] {
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

    func activateAnyScene(for activity: SceneActivity) {
        UIApplication.shared.requestSceneSessionActivation(
            existingScenes(for: .about).first?.session,
            userActivity: SceneActivity.about.activity,
            options: nil
        ) { error in
            Current.Log.error(error)
        }
    }

    @available(iOS 13, *)
    func scene<DelegateType: UIWindowSceneDelegate>(
        for query: SceneQuery<DelegateType>
    ) -> Promise<DelegateType> {
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

        let (promise, resolver) = Promise<DelegateType>.pending()

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
                resolver.reject(error)
            }
        )

        return promise
    }
}
