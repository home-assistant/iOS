import Foundation

/// A decoded `server/state`. Each role object is tri-state on the wire: absent leaves the role
/// unchanged, `null` clears it, and an object replaces it in full.
struct SendspinServerState: Decodable, Equatable {
    enum RoleUpdate<Value: Decodable & Equatable>: Equatable {
        case unchanged
        case cleared
        case updated(Value)
    }

    let metadata: RoleUpdate<SendspinTrackMetadata>
    let controller: RoleUpdate<SendspinControllerState>

    enum CodingKeys: String, CodingKey {
        case metadata
        case controller
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try Self.decodeRole(container, key: .metadata)
        controller = try Self.decodeRole(container, key: .controller)
    }

    private static func decodeRole<Value: Decodable & Equatable>(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> RoleUpdate<Value> {
        guard container.contains(key) else { return .unchanged }
        if try container.decodeNil(forKey: key) { return .cleared }
        let value = try container.decode(Value.self, forKey: key)
        return .updated(value)
    }
}
