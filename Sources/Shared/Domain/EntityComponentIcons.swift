import Foundation
import HAKit

/// A single icon entry from an integration's `icons.json` `entity_component` map, keyed by device
/// class (or `_` for the no-device-class default). Mirrors the frontend's `ComponentIcons` leaf in
/// `home-assistant/frontend` `src/data/icons.ts`. `state_attributes` are omitted: the app resolves
/// the entity's own icon, not per-attribute badges.
public struct EntityComponentIcon: Codable, Equatable {
    public let defaultIcon: String?
    public let state: [String: String]?
    public let range: [String: String]?

    enum CodingKeys: String, CodingKey {
        case defaultIcon = "default"
        case state
        case range
    }
}

/// `domain` → (`device_class` | `_`) → icon entry, as returned by `frontend/get_icons` for the
/// `entity_component` category.
public typealias EntityComponentIconsMap = [String: [String: EntityComponentIcon]]

public struct EntityComponentIconsResponse: HADataDecodable {
    public let resources: EntityComponentIconsMap

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data,
              let resources = dictionary["resources"] else {
            self.resources = [:]
            return
        }
        let jsonData = try JSONSerialization.data(withJSONObject: resources)
        self.resources = (try? JSONDecoder().decode(EntityComponentIconsMap.self, from: jsonData)) ?? [:]
    }
}
