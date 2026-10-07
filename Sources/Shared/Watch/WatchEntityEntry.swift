import Foundation

/// One entity rendered as a home-style row on the watch's area and device screens: the on-the-fly
/// magic item, its resolved info, and the device it belongs to.
///
/// The device travels with the row because both screens group by it — resolving it once here keeps
/// the grouping, the section headers and the drill-in destination reading the same value.
public struct WatchEntityEntry: Identifiable {
    /// The device an entity belongs to, as far as the mirrored registry knows.
    ///
    /// Id and name are carried together on purpose: a group needs both — the id to open the device
    /// screen, the name to title the section — so neither can be present without the other.
    public struct Device: Equatable {
        public let id: String
        public let name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public let item: MagicItem
    public let info: MagicItem.Info
    /// `nil` for entities the registry attributes to no device — YAML/template entities and helpers.
    /// Those are never grouped; they stay loose rows in their section.
    public let device: Device?

    public var id: String { item.serverUniqueId }

    public init(item: MagicItem, info: MagicItem.Info, device: Device? = nil) {
        self.item = item
        self.info = info
        self.device = device
    }
}
