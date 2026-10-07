import Foundation
import GRDB

/// A sidebar dashboard panel, scoped to a server. The `Current.database()`-backed queries live in
/// an extension in the `Shared` module.
public struct AppPanel: Codable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var serverId: String = ""
    public var icon: String? = nil
    public var title: String = ""
    public var path: String = ""
    public var component: String = ""
    public var showInSidebar: Bool = true

    public init(
        id: String = UUID().uuidString,
        serverId: String,
        icon: String? = nil,
        title: String,
        path: String,
        component: String,
        showInSidebar: Bool
    ) {
        self.id = id
        self.serverId = serverId
        self.icon = icon
        self.title = title
        self.path = path
        self.component = component
        self.showInSidebar = showInSidebar
    }
}
