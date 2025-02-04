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

    public enum ItemState: Codable, FetchableRecord, PersistableRecord, Equatable {
        case idle
        case pendingConfirmation
        case progress(Int)
    }

    public static func widgets() throws -> [CustomWidget]? {
        try Current.database.read({ db in
            try CustomWidget.fetchAll(db)
        })
    }
}
