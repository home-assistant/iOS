import Foundation
import Shared

struct CameraCallRequest {
    let cameraEntityId: String
    let cameraName: String
    let server: Server

    init?(
        payload: [AnyHashable: Any],
        servers: ServerManager = Current.servers,
        entityName: (_ entityId: String, _ server: Server) -> String? = { entityId, server in
            HAAppEntity.entity(id: entityId, serverId: server.identifier.rawValue)?.name
        }
    ) {
        guard let entityId = payload["entity_id"] as? String, entityId.hasPrefix("camera.") else {
            return nil
        }
        let webhookServer = (payload["webhook_id"] as? String).flatMap { servers.server(forWebhookID: $0) }
        let onlyServer = servers.all.count == 1 ? servers.all.first : nil
        guard let server = webhookServer ?? onlyServer else {
            return nil
        }
        self.cameraEntityId = entityId
        self.server = server
        self.cameraName = entityName(entityId, server) ?? entityId
    }
}
