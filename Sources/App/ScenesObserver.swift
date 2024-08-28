import Foundation
import HAKit
import PromiseKit
import Shared

enum ScenesObserver {
    static var observer: Observer?

    static func setupObserver() {
        observer = with(Observer()) {
            $0.start()
        }
    }

    final class Observer {
        var container: PerServerContainer<HACancellable>?
        var cachedScenes: [HAScene]?
        func start() {
            container = .init { server in
                .init(
                    Current.api(for: server).connection.caches.states.subscribe({ [weak self] _, states in
                        let scenes = states.all.filter({ $0.domain == Domain.scene.rawValue })
                        self?.handle(scenes: scenes, server: server)
                    })
                )
            }
        }

        enum HandleSceneError: Error {
            case unchanged
        }

        private func handle(scenes: Set<HAEntity>, server: Server) {
            let key = HAScene.cacheKey(serverId: server.identifier.rawValue)
            let scenes = scenes.map { entity in
                HAScene(
                    id: entity.entityId,
                    name: entity.attributes.friendlyName,
                    iconName: entity.attributes.icon
                )
            }.sorted(by: { $0.id < $1.id })
            firstly {
                Current.diskCache.value(for: key) as Promise<[HAScene]>
            }.recover { _ in
                .value([])
            }.then { current -> Promise<Void> in
                guard scenes != current else {
                    return .init(error: HandleSceneError.unchanged)
                }
                return .value(())
            }.then {
                Current.diskCache.set(scenes, for: key)
            }.done {
                Current.Log.info("Updated scenes for server \(server.identifier)")
            }.catch { error in
                if let error = error as? HandleSceneError {
                    if error != .unchanged {
                        Current.Log.error("Failed to cache scenes, error: \(error.localizedDescription)")
                    }
                } else {
                    Current.Log.error("Failed to cache scenes, error: \(error.localizedDescription)")
                }
            }
        }
    }
}
