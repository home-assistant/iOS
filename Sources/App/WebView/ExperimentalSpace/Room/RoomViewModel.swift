import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class RoomViewModel: ObservableObject {
    var allEntities: [HAEntity] = []
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

        // Subscribe to entity changes - entities will be populated when data arrives
        subscribeToEntitiesChanges()
        isLoading = false
    }

    private func buildEntitiesForRoom() {
        do {
            let serverId = server.identifier.rawValue

            // Fetch areas to determine which entities belong to this room
            let areas = try AppArea.fetchAreas(for: serverId)
            guard let targetArea = areas.first(where: { $0.id == roomId }) else {
                allEntities = []
                return
            }

            let roomEntityIds = Set(targetArea.entities)

            // Filter entities by allowed domains and room membership
            let allowedDomains = Set(EntityDisplayService.allowedDomains.map(\.rawValue))
            let filteredEntities = entityStates.values.filter { entity in
                allowedDomains.contains(entity.domain) && roomEntityIds.contains(entity.entityId)
            }

            // Sort by friendly name
            allEntities = filteredEntities.sorted {
                let name1 = $0.attributes.friendlyName ?? $0.entityId
                let name2 = $1.attributes.friendlyName ?? $1.entityId
                return name1 < name2
            }
        } catch {
            Current.Log.error("Failed to build entities for room: \(error.localizedDescription)")
            errorMessage = "Failed to load entities: \(error.localizedDescription)"
        }
    }

    private func subscribeToEntitiesChanges() {
        entityService.subscribeToEntitiesChanges(server: server) { [weak self] states in
            self?.entityStates = states
            self?.buildEntitiesForRoom()
        }
    }

    func unhideEntity(_ entityId: String) {
        hiddenEntityIds.remove(entityId)
        EntityDisplayService.saveHiddenEntities(hiddenEntityIds, for: server)
    }
}
