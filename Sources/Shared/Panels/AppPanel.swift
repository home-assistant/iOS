import Foundation
import GRDB
import HAKit

// `AppPanel` itself lives in the `HAModels` package; these are its database-backed queries.
public extension AppPanel {
    static func panels(serverId: String) throws -> [AppPanel]? {
        try Current.database().read({ db in
            try AppPanel
                .filter(
                    Column(DatabaseTables.AppPanel.serverId.rawValue) == serverId
                )
                .fetchAll(db)
        })
    }

    static func panelsPerServer() throws -> [Server: [AppPanel]] {
        var panelsPerServer: [Server: [AppPanel]] = [:]
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
