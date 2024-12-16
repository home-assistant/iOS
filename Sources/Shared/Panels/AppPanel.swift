import Foundation
import GRDB
import HAKit

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

    public static func panels(serverId: String) throws -> [AppPanel]? {
        try Current.database.read({ db in
            try AppPanel
                .filter(
                    Column(DatabaseTables.AppPanel.serverId.rawValue) == serverId
                )
                .fetchAll(db)
        })
    }

    public static func panelsPerServer() throws -> [Server: [AppPanel]] {
        var panelsPerServer: [Server: [AppPanel]] = [:]
        var finishedPipesCount = 0
        for server in Current.servers.all {
            do {
                if let panels = try AppPanel.panels(serverId: server.identifier.rawValue), !panels.isEmpty {
                    panelsPerServer[server] = panels
                }
            } catch {
                Current.Log.error("Widget error fetching panels for server \(server.identifier.rawValue): \(error)")
            }
        }
        return panelsPerServer
    }
}

struct HAPanelResponse: HADataDecodable {
    let componentName: String?
    let icon: String?
    let title: String?
    let config: String?
    let urlPath: String?

    enum CodingKeys: String, CodingKey {
        case componentName = "component_name"
        case icon
        case title
        case config
        case urlPath = "url_path"
    }

    init(data: HAData) throws {
        self.componentName = try data.decode("component_name")
        self.icon = try data.decode("icon")
        self.title = try data.decode("title")
        self.config = try data.decode("config")
        self.urlPath = try data.decode("url_path")
    }
}
