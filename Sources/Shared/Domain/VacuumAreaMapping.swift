import Foundation
import HAKit

/// The Home Assistant areas a vacuum can be told to clean, read from its entity registry entry.
///
/// A vacuum reports numbered *segments* (rooms as its own firmware knows them); an administrator
/// maps those to Home Assistant areas in the frontend, which stores the result under the entity
/// registry's `options.vacuum.area_mapping` (area id → segment ids). `vacuum.clean_area` then takes
/// **area** ids, so this app only needs the mapping's keys: the set of areas the vacuum can clean.
///
/// Decoded from `config/entity_registry/get`, which is WebSocket-only — see
/// `HATypedRequest.entityRegistryEntry(entityId:)`.
public struct VacuumAreaMapping: HADataDecodable, Equatable {
    /// Home Assistant area ids the vacuum has segments mapped to. Empty when the vacuum supports
    /// cleaning by area but nothing has been mapped yet, which the UI surfaces as an empty state.
    public let areaIds: [String]

    public init(areaIds: [String]) {
        self.areaIds = areaIds
    }

    public init(data: HAData) throws {
        guard case let .dictionary(entry) = data else {
            self.init(areaIds: [])
            return
        }
        self.init(attributes: entry)
    }

    /// An area a vacuum can be told to clean, resolved to something displayable.
    ///
    /// Crosses the WatchConnectivity wire as a plain dictionary: the watch can't read the entity
    /// registry itself (it has no WebSocket), so the phone resolves the mapping's ids against its
    /// area registry and relays these — see `InteractiveImmediateMessages.vacuumCleanableAreas`.
    public struct Area: Equatable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }

        public init?(wireFormat: [String: String]) {
            guard let id = wireFormat["id"], let name = wireFormat["name"] else { return nil }
            self.init(id: id, name: name)
        }

        public var wireFormat: [String: String] {
            ["id": id, "name": name]
        }
    }

    /// Split from the `HAData` decode so the option digging can be unit tested without HAKit.
    public init(attributes: [String: Any]) {
        let options = attributes["options"] as? [String: Any]
        let vacuumOptions = options?["vacuum"] as? [String: Any]
        let mapping = vacuumOptions?["area_mapping"] as? [String: Any]
        // Sorted so the picker's order is stable across fetches; the frontend orders by floor,
        // which needs data these surfaces don't carry.
        self.areaIds = (mapping?.keys).map { Array($0).sorted() } ?? []
    }
}
