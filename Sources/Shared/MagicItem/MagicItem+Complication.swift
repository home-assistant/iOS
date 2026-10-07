import Foundation

public extension MagicItem {
    /// The item that puts an existing watch complication in the watch's list of items.
    ///
    /// Unlike every other item type the id is the complication's own config id, not an entity id —
    /// a complication can be backed by a template and have no entity at all. Confirmation is turned
    /// off because the row runs nothing when tapped — the type itself has no action, whatever the
    /// item's `action` says; it is there to be read.
    ///
    /// The icon is deliberately left out of the customization: the config stores a server-side name
    /// ("mdi:battery") that `Customization.icon` doesn't normalize, so it resolves through
    /// `MagicItem.icon(info:)` from the info's `iconName` instead. Only the color is carried, since
    /// that is what tints the item in the configuration lists.
    init(complication config: WatchComplicationConfig) {
        self.init(
            id: config.id,
            serverId: config.serverId,
            type: .complication,
            customization: .init(iconColor: config.iconColor, requiresConfirmation: false)
        )
    }
}

public extension WatchComplicationConfig {
    /// The complications offered when adding to the watch's item list.
    ///
    /// Rectangular only: it is the one family whose layout — icon, name, and either a progress bar or
    /// a value line — reads correctly at the width of a list row. The other families are designed for
    /// the space around a watch face and would either be unreadably small or lose their gauge.
    static func watchListAddable() throws -> [WatchComplicationConfig] {
        try all().filter { $0.widgetFamily == .rectangular }
    }
}
