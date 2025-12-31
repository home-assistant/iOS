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

    // MARK: - Hidden Entities Management

    static func hiddenEntitiesCacheKey(for server: Server) -> String {
        "home.hiddenEntities." + server.identifier.rawValue
    }

    static func loadHiddenEntities(for server: Server) async -> Set<String> {
        do {
            let hidden: Set<String> = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: hiddenEntitiesCacheKey(for: server))
                    .done { (hidden: Set<String>) in
                        continuation.resume(returning: hidden)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            return hidden
        } catch {
            return []
        }
    }

    static func saveHiddenEntities(_ hiddenEntityIds: Set<String>, for server: Server) {
        Current.diskCache.set(hiddenEntityIds, for: hiddenEntitiesCacheKey(for: server)).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save hidden entities: \(error)")
            }
        }
    }

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

    // MARK: - Entity Filtering

    static func fetchEntitiesWithCategories(serverId: String) throws -> Set<String> {
        do {
            let registryEntities = try Current.database().read { db in
                try AppEntityRegistryListForDisplay
                    .filter(
                        Column(DatabaseTables.AppEntityRegistryListForDisplay.serverId.rawValue) == serverId
                    )
                    .fetchAll(db)
            }
            // Return entity IDs that have a non-nil category (config/diagnostic entities)
            return Set(registryEntities.filter { $0.registry.entityCategory != nil }.map(\.entityId))
        } catch {
            Current.Log.error("Failed to fetch entity registry for filtering: \(error.localizedDescription)")
            return []
        }
    }

    static func filterEntities(
        _ entities: [HAAppEntity],
        serverId: String,
        excludingCategories categorizedEntities: Set<String>
    ) -> [HAAppEntity] {
        entities.filter {
            $0.serverId == serverId &&
                allowedDomains.map(\.rawValue).contains($0.domain) &&
                !categorizedEntities.contains($0.entityId)
        }
    }
}
