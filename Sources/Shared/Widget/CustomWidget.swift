import Foundation
import GRDB

public struct CustomWidget: Codable, FetchableRecord, PersistableRecord, Equatable {
    public var id: String
    public var name: String
    public var items: [MagicItem]
    /// Controls the UI state of the widget when the item tapped requires confirmation [ServerUniqueId: ItemState]
    public var itemsStates: [String: ItemState]

    public init(id: String, name: String, items: [MagicItem], itemsStates: [String: ItemState] = [:]) {
        self.id = id
        self.name = name
        self.items = items
        self.itemsStates = itemsStates
    }

    public mutating func updateItemsStates(_ states: [String: ItemState]) {
        itemsStates = states
    }

    public enum ItemState: String, Codable, FetchableRecord, PersistableRecord, Equatable {
        case idle
        /// The item's icon — or the whole tile, when it isn't split — was tapped and waits to be
        /// confirmed.
        case pendingConfirmation
        /// The rest of a split tile was tapped and waits to be confirmed, so confirming runs the
        /// tile's tap behavior rather than its icon's.
        case pendingTapConfirmation

        public var isPendingConfirmation: Bool {
            self == .pendingConfirmation || self == .pendingTapConfirmation
        }
    }

    public static func widgets() throws -> [CustomWidget]? {
        try Current.database().read({ db in
            try CustomWidget.fetchAll(db)
        })
    }
}
