import AppIntents
import HAKit
import Shared

@available(iOS 17.0, watchOS 10.0, *)
struct IntentCameraEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<GetCameraSnapshotAppIntent>(\.$server)
    var intent

    func entities(for identifiers: [String]) async throws -> [IntentCameraEntity] {
        let cameras = try await cameraEntities().flatMap(\.1)
        let matchedCameras = cameras.filter { identifiers.contains($0.id) }
        let matchedIdentifiers = Set(matchedCameras.map(\.id))
        let fallbackCameras = identifiers
            .filter { matchedIdentifiers.contains($0) == false }
            .compactMap(IntentCameraEntity.init(identifier:))
        return matchedCameras + fallbackCameras
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentCameraEntity> {
        try await cameraCollection(matching: string)
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentCameraEntity> {
        try await cameraCollection()
    }

    private func cameraCollection(matching string: String? = nil) async throws
        -> IntentItemCollection<IntentCameraEntity> {
        let sections = try await cameraEntities().map { server, cameras in
            let filteredCameras: [IntentCameraEntity]
            if let string, string.isEmpty == false {
                filteredCameras = cameras.filter {
                    $0.displayName.localizedCaseInsensitiveContains(string)
                        || $0.entityId.localizedCaseInsensitiveContains(string)
                }
            } else {
                filteredCameras = cameras
            }
            return IntentItemSection<IntentCameraEntity>(
                .init(stringLiteral: server.info.name),
                items: filteredCameras
            )
        }
        return .init(sections: sections)
    }

    private func cameraEntities() async throws -> [(Server, [IntentCameraEntity])] {
        guard let server = intent?.server.getServer() else {
            return []
        }

        let cameras = try await AppIntentServerAPI.entities(server: server, domain: .camera)
        return [(
            server,
            cameras.map { entity in
                IntentCameraEntity(
                    serverId: server.identifier.rawValue,
                    entityId: entity.entityId,
                    displayName: entity.attributes.friendlyName ?? entity.entityId
                )
            }
        )]
    }
}
