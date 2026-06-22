import AppIntents
import HAKit
import PromiseKit
import Shared

@available(iOS 17.0, *)
struct IntentCameraEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Camera")
    static let defaultQuery = IntentCameraEntityQuery()

    let id: String
    let serverId: String
    let entityId: String
    let displayName: String

    var displayRepresentation: DisplayRepresentation {
        .init(
            title: .init(stringLiteral: displayName),
            subtitle: .init(stringLiteral: entityId),
            image: .init(systemName: "camera")
        )
    }
}

@available(iOS 17.0, *)
struct IntentCameraEntityQuery: EntityQuery, EntityStringQuery {
    @IntentParameterDependency<GetCameraSnapshotAppIntent>(\.$server)
    var intent

    func entities(for identifiers: [String]) async throws -> [IntentCameraEntity] {
        let cameras = try await cameraEntities().flatMap(\.1)
        let matchedCameras = cameras.filter { identifiers.contains($0.id) }
        let matchedIdentifiers = Set(matchedCameras.map(\.id))
        let fallbackCameras = identifiers
            .filter { matchedIdentifiers.contains($0) == false }
            .compactMap(Self.cameraEntity(for:))
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
        guard let server = intent?.server.getServer(),
              let connection = Current.api(for: server)?.connection else {
            return []
        }

        let cameras = try await connection.cameraEntities().async(timeout: 10)
        return [(
            server,
            cameras.map { entity in
                Self.cameraEntity(server: server, entity: entity)
            }
        )]
    }

    private static func cameraEntity(server: Server, entity: HAEntity) -> IntentCameraEntity {
        IntentCameraEntity(
            id: "\(server.identifier.rawValue)::\(entity.entityId)",
            serverId: server.identifier.rawValue,
            entityId: entity.entityId,
            displayName: entity.attributes.friendlyName ?? entity.entityId
        )
    }

    private static func cameraEntity(for identifier: String) -> IntentCameraEntity? {
        let components = identifier.components(separatedBy: "::")
        guard components.count == 2 else {
            return nil
        }

        return IntentCameraEntity(
            id: identifier,
            serverId: components[0],
            entityId: components[1],
            displayName: components[1]
        )
    }
}

private extension HAConnection {
    func cameraEntities() -> Promise<[HAEntity]> {
        caches.states().once().promise
            .map(\.all)
            .filterValues { $0.domain == "camera" }
            .mapValues { $0 }
            .map { entities in
                entities.sorted {
                    ($0.attributes.friendlyName ?? $0.entityId).localizedCaseInsensitiveCompare(
                        $1.attributes.friendlyName ?? $1.entityId
                    ) == .orderedAscending
                }
            }
    }
}
