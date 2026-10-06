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

/// Which dashboard has a view for every area, so a deep link can land on one.
///
/// Core registers the built-in dashboard as a panel of its own — component `home`, not `lovelace` —
/// and that panel is what answers `/home/areas-<area_id>` (`ha-panel-home` in
/// home-assistant/frontend). It always has a view per area, so it settles the question whenever the
/// server has it, and the widgets can read it straight out of the stored panels.
///
/// Servers old enough not to have it may still have a dashboard built by the frontend's *areas*
/// strategy, which also gives every area a view. That one can only be found by asking each dashboard
/// for its config, so the app does it while it refreshes its panels and keeps the answer in the app
/// group. A server with neither has no area view at all, and an area opens in Settings instead.
public extension AppPanel {
    /// The component core gives the built-in dashboard.
    static let homeDashboardComponent = "home"
    /// The component every lovelace dashboard has, built-in or user-made.
    static let lovelaceComponent = "lovelace"
    /// The strategy that gives a dashboard a view per area.
    static let areasStrategy = "areas"

    /// The dashboard an area's view lives on for this server, or `nil` when it has none.
    ///
    /// Reads the panels the app has stored, so a widget resolves this itself and only falls back to
    /// what the app worked out over the websocket for servers without the built-in dashboard.
    static func areasDashboardPath(serverId: String) -> String? {
        if let panels = try? panels(serverId: serverId), let home = homeDashboardPath(in: panels) {
            return home
        }
        return Current.settingsStore.prefs.string(forKey: areasDashboardKey(serverId: serverId))
    }

    static func setAreasDashboardPath(_ path: String?, serverId: String) {
        let key = areasDashboardKey(serverId: serverId)
        if let path {
            Current.settingsStore.prefs.set(path, forKey: key)
        } else {
            Current.settingsStore.prefs.removeObject(forKey: key)
        }
    }

    /// The built-in dashboard's path, when the server registers it.
    static func homeDashboardPath(in panels: [AppPanel]) -> String? {
        panels.first(where: { $0.component == homeDashboardComponent })?.path
    }

    /// The same, from the panel list the server just sent.
    static func homeDashboardPath(in panels: HAPanels) -> String? {
        panels.allPanels.first(where: { $0.component == homeDashboardComponent })?.path
    }

    /// The dashboard to open an area on, given each dashboard's strategy: the built-in one when the
    /// server has it, otherwise the first dashboard the areas strategy builds.
    static func resolveAreasDashboardPath(
        panels: HAPanels,
        strategies: [String: String]
    ) -> String? {
        if let home = homeDashboardPath(in: panels) {
            return home
        }
        return panels.allPanels
            .filter { $0.component == lovelaceComponent }
            .map(\.path)
            .first(where: { strategies[$0] == areasStrategy })
    }

    /// Works out where an area opens on this server and stores it for the widgets to read.
    ///
    /// Costs nothing on a server with the built-in dashboard, which is every server since core
    /// 2026.3. Takes the connection rather than reaching for one, so the round trips can be tested.
    static func updateAreasDashboard(panels: HAPanels, serverId: String, on connection: HAConnection) async {
        guard homeDashboardPath(in: panels) == nil else {
            // The widget reads this one out of the stored panels; nothing to keep.
            setAreasDashboardPath(nil, serverId: serverId)
            return
        }
        var strategies: [String: String] = [:]
        for path in panels.allPanels.filter({ $0.component == lovelaceComponent }).map(\.path) {
            strategies[path] = await dashboardStrategy(on: connection, path: path)
        }
        setAreasDashboardPath(
            resolveAreasDashboardPath(panels: panels, strategies: strategies),
            serverId: serverId
        )
    }

    /// The strategy a dashboard is built by, or `nil` for one that is not built by a strategy — and
    /// for a dashboard that has no stored config at all, which answers with an error.
    static func dashboardStrategy(on connection: HAConnection, path: String) async -> String? {
        await withCheckedContinuation { continuation in
            // The default dashboard is addressed by a null path, the way the frontend addresses it.
            let urlPath: Any = path == defaultDashboardPath ? NSNull() : path
            connection.send(
                HARequest(type: .webSocket("lovelace/config"), data: ["url_path": urlPath, "force": false])
            ) { result in
                guard case let .success(data) = result,
                      case let .dictionary(dictionary) = data,
                      let strategy = dictionary["strategy"] as? [String: Any],
                      let type = strategy["type"] as? String else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: type)
            }
        }
    }

    /// The path of the dashboard core serves at the root, which the websocket addresses as null.
    static let defaultDashboardPath = "lovelace"

    private static func areasDashboardKey(serverId: String) -> String {
        "areas-dashboard-\(serverId)"
    }
}
