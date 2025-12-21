import Foundation
import Shared

final class CameraListViewModel: ObservableObject {
    @Published var cameras: [HAAppEntity] = []
    @Published var searchTerm = ""
    @Published var selectedServerId: String?

    private let initialServerId: String?
    private let controlEntityProvider = ControlEntityProvider(domains: [.camera])

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
    }

    var filteredCameras: [HAAppEntity] {
        cameras.filter { camera in
            let matchesServer = selectedServerId == nil || camera.serverId == selectedServerId
            let matchesSearch = searchTerm.count <= 2 || 
                camera.name.lowercased().contains(searchTerm.lowercased()) ||
                camera.entityId.lowercased().contains(searchTerm.lowercased())
            return matchesServer && matchesSearch
        }
    }

    func server(for camera: HAAppEntity) -> Server? {
        Current.servers.all.first(where: { $0.identifier.rawValue == camera.serverId })
    }
}
