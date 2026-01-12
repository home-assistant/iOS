import Foundation
import GRDB
import PromiseKit
import Shared

@available(iOS 16.0, *)
final class CameraListViewModel: ObservableObject {
    @Published var cameras: [HAAppEntity] = []
    @Published var searchTerm = ""
    @Published var selectedServerId: String?

    private let initialServerId: String?
    private let controlEntityProvider = ControlEntityProvider(domains: [.camera])
    private var entityToAreaMap: [String: String] = [:]
    private var cameraOrderStorage: [String: CameraListConfiguration] = [:] // [serverId: CameraOrderStorage]
    private let database: DatabaseQueue

    var shouldShowServerPicker: Bool {
        // Only show server picker if not initialized with a specific serverId
        initialServerId == nil
    }

    init(serverId: String? = nil, database: DatabaseQueue = .appDatabase) {
        self.initialServerId = serverId
        self.selectedServerId = serverId
        self.database = database
        loadCameraOrders()
    }

    func fetchCameras() {
        let entitiesPerServer = controlEntityProvider.getEntities()
        cameras = entitiesPerServer.flatMap(\.1)

        if selectedServerId == nil {
            selectedServerId = Current.servers.all.first?.identifier.rawValue
        }

        // Build area mapping for all servers
        buildAreaMapping()
    }

    private func buildAreaMapping() {
        entityToAreaMap.removeAll()

        for server in Current.servers.all {
            do {
                let areas = try AppArea.fetchAreas(for: server.identifier.rawValue)
                for area in areas {
                    for entityId in area.entities {
                        entityToAreaMap[entityId] = area.name
                    }
                }
            } catch {
                Current.Log.error("Failed to fetch areas for server \(server.info.name): \(error.localizedDescription)")
            }
        }
    }

    var filteredCameras: [HAAppEntity] {
        cameras.filter { camera in
            let matchesServer = selectedServerId == nil || camera.serverId == selectedServerId
            let matchesSearch = searchTerm.count < 2 ||
                camera.name.lowercased().contains(searchTerm.lowercased()) ||
                camera.entityId.lowercased().contains(searchTerm.lowercased())
            return matchesServer && matchesSearch
        }
    }

    var groupedCameras: [(area: String, cameras: [HAAppEntity])] {
        let filtered = filteredCameras

        // Group cameras by area
        let grouped = Dictionary(grouping: filtered) { camera -> String in
            areaName(for: camera) ?? L10n.CameraList.noArea
        }

        // Check if we have a custom section order for this server
        if let serverId = selectedServerId,
           let storage = cameraOrderStorage[serverId],
           let sectionOrder = storage.sectionOrder {
            // Filter section order to only include areas that currently exist
            let existingAreas = Set(grouped.keys)
            let validOrderedSections = sectionOrder.filter { existingAreas.contains($0) }

            // Find any new sections not in the saved order
            let newSections = existingAreas.subtracting(validOrderedSections)
                .sorted { lhs, rhs in
                    if lhs == L10n.CameraList.noArea { return false }
                    if rhs == L10n.CameraList.noArea { return true }
                    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
                }

            // Combine ordered sections + new sections
            let finalOrder = validOrderedSections + newSections

            return finalOrder.compactMap { area in
                guard let cameras = grouped[area] else { return nil }
                return (area: area, cameras: sortCamerasInArea(cameras, area: area))
            }
        }

        // Default: Sort groups alphabetically, but put "No Area" last
        return grouped.sorted { lhs, rhs in
            if lhs.key == L10n.CameraList.noArea { return false }
            if rhs.key == L10n.CameraList.noArea { return true }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }.map { (area: $0.key, cameras: sortCamerasInArea($0.value, area: $0.key)) }
    }

    private func sortCamerasInArea(_ cameras: [HAAppEntity], area: String) -> [HAAppEntity] {
        guard let serverId = selectedServerId,
              let storage = cameraOrderStorage[serverId],
              let order = storage.areaOrders[area] else {
            // No custom order, sort alphabetically
            return cameras.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        // Create a dictionary for quick lookup
        let cameraDict = Dictionary(uniqueKeysWithValues: cameras.map { ($0.entityId, $0) })

        // First, add cameras in the saved order
        var sortedCameras: [HAAppEntity] = []
        for entityId in order {
            if let camera = cameraDict[entityId] {
                sortedCameras.append(camera)
            }
        }

        // Then add any new cameras not in the saved order (sorted alphabetically)
        let orderedIds = Set(order)
        let newCameras = cameras.filter { !orderedIds.contains($0.entityId) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        sortedCameras.append(contentsOf: newCameras)

        return sortedCameras
    }

    func moveCameras(in area: String, from source: IndexSet, to destination: Int) {
        guard let serverId = selectedServerId else { return }

        // Get current cameras for this area
        let group = groupedCameras.first(where: { $0.area == area })
        guard var cameras = group?.cameras else { return }

        // Perform the move
        cameras.move(fromOffsets: source, toOffset: destination)

        // Save the new order
        let newOrder = cameras.map(\.entityId)

        if cameraOrderStorage[serverId] == nil {
            cameraOrderStorage[serverId] = CameraListConfiguration(
                serverId: serverId,
                areaOrders: [:],
                sectionOrder: nil
            )
        }
        cameraOrderStorage[serverId]?.areaOrders[area] = newOrder

        saveCameraOrders()

        // Trigger UI update
        objectWillChange.send()
    }

    func saveSectionOrder(_ sections: [String]) {
        guard let serverId = selectedServerId else { return }

        if cameraOrderStorage[serverId] == nil {
            cameraOrderStorage[serverId] = CameraListConfiguration(
                serverId: serverId,
                areaOrders: [:],
                sectionOrder: sections
            )
        } else {
            cameraOrderStorage[serverId]?.sectionOrder = sections
        }

        saveCameraOrders()

        // Trigger UI update
        objectWillChange.send()
    }

    private func loadCameraOrders() {
        do {
            let configurations = try database.read { db in
                try CameraListConfiguration.fetchAll(db)
            }

            for config in configurations {
                cameraOrderStorage[config.serverId] = config
            }
        } catch {
            Current.Log.error("Failed to load camera orders from GRDB: \(error.localizedDescription)")
        }
    }

    private func saveCameraOrders() {
        do {
            try database.write { db in
                for (serverId, storage) in cameraOrderStorage {
                    var config = storage
                    config.serverId = serverId
                    try config.save(db)
                }
            }
        } catch {
            Current.Log.error("Failed to save camera orders to GRDB: \(error.localizedDescription)")
        }
    }

    func server(for camera: HAAppEntity) -> Server? {
        Current.servers.all.first(where: { $0.identifier.rawValue == camera.serverId })
    }

    func areaName(for camera: HAAppEntity) -> String? {
        entityToAreaMap[camera.entityId]
    }
}
