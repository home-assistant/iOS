import Foundation
import GRDB

public struct WatchConfig: Codable, FetchableRecord, PersistableRecord {
    public var id = UUID().uuidString
    public var showAssist: Bool = true
    public var items: [MagicItem] = []

    public init(id: String = UUID().uuidString, showAssist: Bool = true, items: [MagicItem] = []) {
        self.id = id
        self.showAssist = showAssist
        self.items = items
    }
}
