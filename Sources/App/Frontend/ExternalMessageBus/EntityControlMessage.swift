import Foundation

/// The frontend's `entity/controlled` message: one service call the user made, and the entities it
/// was addressed to.
struct EntityControlMessage: Equatable {
    let entityIds: [String]
    let domain: String
    let service: String

    /// Reads the message off the bus payload, or nothing when a field is missing or names no entity.
    init?(payload: [String: Any]?) {
        guard let payload,
              let entityIds = payload["entity_ids"] as? [String],
              !entityIds.isEmpty,
              let domain = payload["domain"] as? String,
              let service = payload["service"] as? String else {
            return nil
        }
        self.entityIds = entityIds
        self.domain = domain
        self.service = service
    }
}
