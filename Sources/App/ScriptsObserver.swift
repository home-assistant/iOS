import Foundation
import Shared
import HAKit
import PromiseKit
import WidgetKit

final class ScriptsObserver {
    static func cacheKey(serverId: String) -> String {
        "scripts-cache-\(serverId)"
    }

    static var observer: Observer?

    static func setupObserver() {
        observer = with(Observer()) {
            $0.start()
        }
    }

    final class Observer {
        var container: PerServerContainer<HACancellable>?
        var cachedScripts: [HAScript]?
        func start() {
            container = .init { server in
                    .init(
                        Current.api(for: server).connection.caches.states.subscribe({ [weak self] _, states in
                            let scripts = states.all.filter({ $0.domain == Domain.script.rawValue })
                            self?.handle(scripts: scripts, server: server)
                        })
                    )
            }
        }

        enum HandleScriptsError: Error {
            case unchanged
        }

        private func handle(scripts: Set<HAEntity>, server: Server) {
            let key = ScriptsObserver.cacheKey(serverId: server.identifier.rawValue)
            let scripts = scripts.map { entity in
                HAScript(id: entity.entityId, name: entity.attributes.friendlyName)
            }
            firstly {
                Current.diskCache.value(for: key) as Promise<[HAScript]>
            }.recover { _ in
                    .value([])
            }.then { current -> Promise<Void> in
                guard scripts != current else {
                    return .init(error: HandleScriptsError.unchanged)
                }

                WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.scripts.rawValue)
                return .value(())
            }.then {
                Current.diskCache.set(scripts, for: key)
            }.done {
                Current.Log.info("Updated scripts widget timeline and cache due to server \(server.identifier)")
            }.catch { error in
                if !(error is HandleScriptsError) {
                    Current.Log.verbose("Didn't reload scripts widget from server \(server.identifier): \(error)")
                }
            }
        }
    }
}