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

    private let entityService = EntityDisplayService()

    init(server: Server, roomId: String, roomName: String) {
        self.server = server
        self.roomId = roomId
        self.roomName = roomName
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        // Load hidden entities first
        hiddenEntityIds = await EntityDisplayService.loadHiddenEntities(for: server)

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
                EntityDisplayService.allowedDomains.map(\.rawValue).contains($0.domain)
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
        entityService.subscribeToEntitiesChanges(server: server) { [weak self] states in
            self?.entityStates = states
        }
    }

    func unhideEntity(_ entityId: String) {
        hiddenEntityIds.remove(entityId)
        EntityDisplayService.saveHiddenEntities(hiddenEntityIds, for: server)
    }
}
