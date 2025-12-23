import Foundation
import GRDB
import HAKit
import Shared
import SwiftUI

@available(iOS 26.0, *)
@Observable
@MainActor
final class HomeViewModel: ObservableObject {
    var groupedEntities: [RoomSection] = []
    var isLoading = false
    var errorMessage: String?
    var server: Server
    var entityStates: [String: HAEntity] = [:]

    private var entitiesSubscriptionToken: HACancellable?

    struct RoomSection: Identifiable, Equatable {
        let id: String
        let name: String
        let entities: [HAAppEntity]
    }

    private var allowedDomains: [Domain] = [
        .light,
        .cover,
    ]

    init(server: Server) {
        self.server = server
    }

    func loadEntities() async {
        isLoading = true
        errorMessage = nil

        let serverId = server.identifier.rawValue

        do {
            // Fetch all entities from database
            let allEntities = try HAAppEntity.config() ?? []

            // Filter entities for the selected server
            let serverEntities = allEntities.filter {
                $0.serverId == serverId &&
                    allowedDomains.map(\.rawValue).contains($0.domain)
            }

            // Fetch all areas for this server
            let areas = try AppArea.fetchAreas(for: serverId)

            // Create a map of entity ID to area
            var entityToArea: [String: AppArea] = [:]
            for area in areas {
                for entityId in area.entities {
                    entityToArea[entityId] = area
                }
            }

            // Group entities by area
            var roomGroups: [String: (area: AppArea?, entities: [HAAppEntity])] = [:]

            for entity in serverEntities {
                if let area = entityToArea[entity.entityId] {
                    let key = area.id
                    if roomGroups[key] == nil {
                        roomGroups[key] = (area, [])
                    }
                    roomGroups[key]?.entities.append(entity)
                } else {
                    // Entities without an area go to "No Area" section
                    let noAreaKey = "no_area"
                    if roomGroups[noAreaKey] == nil {
                        roomGroups[noAreaKey] = (nil, [])
                    }
                    roomGroups[noAreaKey]?.entities.append(entity)
                }
            }

            // Convert to sorted array of RoomSections
            var sections: [RoomSection] = []

            // Add sections with areas first, sorted by name
            let areasWithEntities = roomGroups
                .filter { $0.value.area != nil }
                .sorted { $0.value.area!.name < $1.value.area!.name }

            for (key, value) in areasWithEntities {
                sections.append(RoomSection(
                    id: key,
                    name: value.area!.name,
                    entities: value.entities.sorted { $0.name < $1.name }
                ))
            }

            // Add "No Area" section at the end if it exists
            if let noAreaGroup = roomGroups["no_area"], !noAreaGroup.entities.isEmpty {
                sections.append(RoomSection(
                    id: "no_area",
                    name: L10n.noArea,
                    entities: noAreaGroup.entities.sorted { $0.name < $1.name }
                ))
            }

            groupedEntities = sections
            isLoading = false
            subscribeToEntitiesChanges()
        } catch {
            Current.Log.error("Failed to load entities for HomeView: \(error.localizedDescription)")
            errorMessage = "Failed to load entities: \(error.localizedDescription)"
            isLoading = false
        }
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

        // Guarantee fresh data
        Current.api(for: server)?.connection.disconnect()
        entitiesSubscriptionToken = Current.api(for: server)?.connection.caches.states(filter)
            .subscribe { [weak self] _, states in
                Task { @MainActor [weak self] in
                    self?.entityStates = states.all.reduce(into: [:]) { $0[$1.entityId] = $1 }
                }
            }
    }
}
