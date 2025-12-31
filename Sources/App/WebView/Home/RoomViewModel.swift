import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class RoomViewModel: ObservableObject {
    var allEntities: [HAAppEntity] = []
    var isLoading = false
    var errorMessage: String?
    var server: Server
    var entityStates: [String: HAEntity] = [:]
    var hiddenEntityIds: Set<String> = []
    let roomId: String
    let roomName: String

    private var entitiesSubscriptionToken: HACancellable?

    private var allowedDomains: [Domain] = [
        .light,
        .cover,
        .switch,
        .fan,
    ]

    init(server: Server, roomId: String, roomName: String) {
        self.server = server
        self.roomId = roomId
        self.roomName = roomName
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        // Load hidden entities first
        await loadHiddenEntitiesIfNeeded()

        do {
            let entities = try await fetchAllEntitiesForRoom()
            allEntities = entities.sorted { $0.name < $1.name }
            isLoading = false
            subscribeToEntitiesChanges()
        } catch {
            Current.Log.error("Failed to load entities for RoomView: \(error.localizedDescription)")
            errorMessage = "Failed to load entities: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func fetchAllEntitiesForRoom() async throws -> [HAAppEntity] {
        let serverId = server.identifier.rawValue

        // Fetch ALL entities (including hidden) using .all
        let allEntities = try HAAppEntity.config(include: [.all]) ?? []

        // Filter to this server and allowed domains
        let serverEntities = allEntities.filter {
            $0.serverId == serverId &&
                allowedDomains.map(\.rawValue).contains($0.domain)
        }

        // Fetch areas to map entities to rooms
        let areas = try AppArea.fetchAreas(for: serverId)
        let targetArea = areas.first { $0.id == roomId }

        guard let targetArea else {
            return []
        }

        // Filter entities that belong to this room
        let roomEntityIds = Set(targetArea.entities)
        return serverEntities.filter { roomEntityIds.contains($0.entityId) }
    }

    private func subscribeToEntitiesChanges() {
        entitiesSubscriptionToken?.cancel()

        var filter: [String: Any] = [:]
        if server.info.version > .canSubscribeEntitiesChangesWithFilter {
            filter = [
                "include": [
                    "domains": allowedDomains.map(\.rawValue),
                ],
            ]
        }

        entitiesSubscriptionToken = Current.api(for: server)?.connection.caches.states(filter)
            .subscribe { [weak self] _, states in
                Task { @MainActor [weak self] in
                    self?.entityStates = states.all.reduce(into: [:]) { $0[$1.entityId] = $1 }
                }
            }
    }

    func unhideEntity(_ entityId: String) {
        // Remove from the hidden set
        hiddenEntityIds.remove(entityId)

        // Update the cache
        Task {
            let hiddenEntitiesCacheKey = "home.hiddenEntities." + server.identifier.rawValue

            Current.diskCache.set(hiddenEntityIds, for: hiddenEntitiesCacheKey).pipe { result in
                if case let .rejected(error) = result {
                    Current.Log.error("Failed to save hidden entities: \(error)")
                }
            }
        }
    }

    // MARK: - Hidden Entities

    private var hiddenEntitiesCacheKey: String {
        "home.hiddenEntities." + server.identifier.rawValue
    }

    private func loadHiddenEntitiesIfNeeded() async {
        do {
            let hidden: Set<String> = try await withCheckedThrowingContinuation { continuation in
                Current.diskCache
                    .value(for: hiddenEntitiesCacheKey)
                    .done { (hidden: Set<String>) in
                        continuation.resume(returning: hidden)
                    }
                    .catch { error in
                        continuation.resume(throwing: error)
                    }
            }
            hiddenEntityIds = hidden
        } catch {
            // No hidden entities cached, start with empty set
            hiddenEntityIds = []
        }
    }
}
