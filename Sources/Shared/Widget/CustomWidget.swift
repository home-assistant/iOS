import Foundation
import GRDB

public struct CustomWidget: Codable, FetchableRecord, PersistableRecord, Equatable {
    public var id: String = UUID().uuidString
    public var name: String = ""
    public var items: [MagicItem] = []
    /// Controls the UI state of the widget when the item tapped requires confirmation
    public var itemsStates: [MagicItem: ItemState] = [:]

    public init(name: String, items: [MagicItem]) {
        self.name = name
        self.items = items
        self.itemsStates = [:]
    }

    public enum ItemState: String, Codable, FetchableRecord, PersistableRecord, Equatable {
        case idle
        case pendingConfirmation
    }

    public static func widgets() throws -> [CustomWidget]? {
        try Current.database.read({ db in
            try CustomWidget.fetchAll(db)
        })
    }
}
