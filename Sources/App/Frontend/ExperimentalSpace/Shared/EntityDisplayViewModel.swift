import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

/// Protocol defining common functionality for view models that display entities
@available(iOS 26.0, *)
@MainActor
protocol EntityDisplayViewModel: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    var server: Server { get }
    var entityStates: [String: HAEntity] { get set }
    var hiddenEntityIds: Set<String> { get set }

    func loadEntities() async
}

/// Shared functionality for entity display view models
@available(iOS 26.0, *)
@MainActor
final class EntityDisplayService {
    static let allowedDomains: [Domain] = [
        .light,
        .cover,
        .switch,
        .fan,
    ]

    private var entitiesSubscriptionToken: HACancellable?

    // MARK: - Entity Subscription

    func subscribeToEntitiesChanges(
        server: Server,
        onUpdate: @escaping @MainActor ([String: HAEntity]) -> Void
    ) {
        entitiesSubscriptionToken?.cancel()

        var filter: [String: Any] = [:]
        if server.info.version > .canSubscribeEntitiesChangesWithFilter {
            filter = [
                "include": [
                    "domains": Self.allowedDomains.map(\.rawValue),
                ],
            ]
        }

        // Guarantee fresh data
        Current.api(for: server)?.connection.disconnect()
        entitiesSubscriptionToken = Current.api(for: server)?.connection.caches.states(filter)
            .subscribe { _, states in
                Task { @MainActor in
                    let entityStates = states.all.reduce(into: [:]) { $0[$1.entityId] = $1 }
                    onUpdate(entityStates)
                }
            }
    }

    func cancelSubscription() {
        entitiesSubscriptionToken?.cancel()
    }
}
