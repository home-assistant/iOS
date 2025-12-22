import Foundation
import Shared

final class CameraListViewModel: ObservableObject {
    @Published var cameras: [HAAppEntity] = []
    @Published var searchTerm = ""
    @Published var selectedServerId: String?

    private let initialServerId: String?
    private let controlEntityProvider = ControlEntityProvider(domains: [.camera])
    private var entityToAreaMap: [String: String] = [:]

    var shouldShowServerPicker: Bool {
        // Only show server picker if not initialized with a specific serverId
        initialServerId == nil
    }

    init(serverId: String? = nil) {
        self.initialServerId = serverId
        self.selectedServerId = serverId
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
        
        // Sort groups alphabetically, but put "No Area" last
        return grouped.sorted { lhs, rhs in
            if lhs.key == L10n.CameraList.noArea { return false }
            if rhs.key == L10n.CameraList.noArea { return true }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
        }.map { (area: $0.key, cameras: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
    }

    func server(for camera: HAAppEntity) -> Server? {
        Current.servers.all.first(where: { $0.identifier.rawValue == camera.serverId })
    }

    func areaName(for camera: HAAppEntity) -> String? {
        entityToAreaMap[camera.entityId]
    }
}
