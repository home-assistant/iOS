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
    var sectionOrder: [String] = []

    struct RoomSection: Identifiable, Equatable {
        let id: String
        let name: String
        let entities: [HAAppEntity]
    }

    private var entitiesSubscriptionToken: HACancellable?

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
                }
                // Entities without an area are now skipped
            }

            // Convert to sorted array of RoomSections
            var sections: [RoomSection] = []

            // Add sections with areas, sorted by name
            let areasWithEntities = roomGroups
                .sorted { $0.value.area!.name < $1.value.area!.name }

            for (key, value) in areasWithEntities {
                sections.append(RoomSection(
                    id: key,
                    name: value.area!.name,
                    entities: value.entities.sorted { $0.name < $1.name }
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

    func filteredSections(sectionOrder: [String], selectedSectionIds: Set<String>) -> [RoomSection] {
        // Apply saved ordering
        let orderedSections: [RoomSection]
        if sectionOrder.isEmpty {
            orderedSections = groupedEntities
        } else {
            let orderIndex = Dictionary(uniqueKeysWithValues: sectionOrder.enumerated().map { ($1, $0) })
            orderedSections = groupedEntities.sorted { a, b in
                let ia = orderIndex[a.id] ?? Int.max
                let ib = orderIndex[b.id] ?? Int.max
                if ia == ib { return a.name < b.name }
                return ia < ib
            }
        }
        // If no sections are selected, show all
        guard !selectedSectionIds.isEmpty else {
            return orderedSections
        }
        // Otherwise, filter to only selected sections
        return orderedSections.filter { selectedSectionIds.contains($0.id) }
    }

    func toggledSelection(
        for sectionId: String,
        current selected: Set<String>,
        allowMultipleSelection: Bool
    ) -> Set<String> {
        var updated = selected
        if allowMultipleSelection {
            if updated.contains(sectionId) {
                updated.remove(sectionId)
            } else {
                updated.insert(sectionId)
            }
        } else {
            if updated.contains(sectionId) {
                updated.removeAll()
            } else {
                updated = [sectionId]
            }
        }
        return updated
    }

    // MARK: - Section Order Persistence

    private var sectionOrderCacheKey: String {
        // Use a server-specific key; prefer a stable identifier if available
        "home.sections.order." + server.identifier.rawValue
    }

    func loadSectionOrderIfNeeded() {
        Current.diskCache
            .value(for: sectionOrderCacheKey)
            .done { [weak self] (order: [String]) in
                self?.sectionOrder = order
            }
            .catch { [weak self] _ in
                guard let self else { return }
                sectionOrder = groupedEntities.map(\.id)
            }
    }

    func saveSectionOrder() {
        Current.diskCache.set(sectionOrder, for: sectionOrderCacheKey).pipe { result in
            if case let .rejected(error) = result {
                Current.Log.error("Failed to save sections order: \(result)")
            }
        }
    }
}
