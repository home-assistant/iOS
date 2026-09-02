import HAKit

public extension HACachesContainer {
    var panels: HACache<HAPanels> { self[HAPanelsCacheKey.self] }
}

public struct HAPanel: HADataDecodable, Codable, Equatable {
    public var icon: String?
    public var title: String
    public var path: String
    public var component: String
    /// Whether the server suggests this panel in the sidebar.
    ///
    /// Core only started reporting this in 2026.3; before that the key was absent. It is _not_ a
    /// signal for "is this a dashboard the user has": dashboards with "Show in sidebar" turned off
    /// and the built-in `home`/`light`/`security`/`climate`/`maintenance` dashboards are all
    /// reported as `false`, yet the frontend still offers all of them as navigation targets.
    public var showInSidebar: Bool
    /// `default_visible` from core 2026.3+, `nil` on older servers. Sidebar visibility is stored per
    /// user in the frontend, so this is only the default that the sidebar starts from.
    public var defaultVisible: Bool?
    /// The `title` exactly as the server sent it; `nil` when the server sent none. The frontend hides
    /// untitled panels from its sidebar, so keep the distinction that `title`'s fallback erases.
    public var rawTitle: String?

    public init(data: HAData) throws {
        let component: String = try data.decode("component_name")
        self.component = component
        let fallbackIcon: String? = { () -> String? in
            switch component {
            case "profile": return "mdi:account"
            case "lovelace": return "mdi:view-dashboard"
            default: return nil
            }
        }()

        self.showInSidebar = data.decode("show_in_sidebar", fallback: true)
        self.defaultVisible = try? data.decode("default_visible")
        self.icon = data.decode("icon", fallback: fallbackIcon)
        let path: String = try data.decode("url_path")
        self.path = path

        // Servers before 2026.3 don't send a title for dashboards hidden from the sidebar; the
        // frontend falls back to the path for those, which reads better than the component name.
        let rawTitle: String? = try? data.decode("title")
        self.rawTitle = rawTitle
        let title = rawTitle ?? path

        let possibleFrontendKey: String
        if path == "lovelace" {
            possibleFrontendKey = "panel::states"
        } else {
            possibleFrontendKey = "panel::\(title)"
        }

        self.title = Current.localized.frontend(possibleFrontendKey) ?? title
    }

    public init(
        icon: String?,
        title: String,
        path: String,
        component: String,
        showInSidebar: Bool,
        defaultVisible: Bool? = nil,
        rawTitle: String? = nil
    ) {
        self.icon = icon
        self.title = title
        self.path = path
        self.component = component
        self.showInSidebar = showInSidebar
        self.defaultVisible = defaultVisible
        self.rawTitle = rawTitle
    }
}

public struct HAPanels: HADataDecodable, Codable, Equatable {
    public var panelsByPath: [String: HAPanel]
    public var allPanels: [HAPanel]

    /// Panels the frontend never offers as a navigation target.
    /// `SYSTEM_PANELS` in https://github.com/home-assistant/frontend/blob/dev/src/data/panel.ts
    private static let systemPanelPaths: Set<String> = ["_my_redirect", "notfound"]
    /// Add-on ingress panels, which the frontend lists separately from its own panels.
    private static let ingressPanelComponent = "app"
    /// The built-in dashboard the frontend defaults to since core 2026.3.
    private static let overviewPath = "home"
    /// The other dashboards core 2026.3+ registers built in, none of which are in the sidebar.
    private static let builtInDashboardPaths: Set<String> = ["light", "security", "climate", "maintenance"]

    public init(panelsByPath: [String: HAPanel]) {
        self.panelsByPath = panelsByPath
        self.allPanels = panelsByPath.values.sorted(by: Self.isSortedBefore)
    }

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data else {
            throw HADataError.missingKey("root")
        }

        // A panel we can't decode shouldn't cost the user every other panel, so decode leniently.
        let panels = dictionary.compactMap { key, value -> (String, HAPanel)? in
            guard !Self.isSystemPanel(path: key) else { return nil }

            do {
                let panel = try HAPanel(data: .init(value: value))
                guard panel.component != Self.ingressPanelComponent else { return nil }
                return (key, panel)
            } catch {
                Current.Log.error("Failed to decode panel \(key): \(error)")
                return nil
            }
        }

        self.init(panelsByPath: Dictionary(panels, uniquingKeysWith: { first, _ in first }))
    }

    private static func isSystemPanel(path: String) -> Bool {
        // Underscore-prefixed paths are internal panels, e.g. `_my_redirect`.
        path.hasPrefix("_") || systemPanelPaths.contains(path)
    }

    /// The order the frontend gives panels that aren't dashboards.
    /// `SORT_VALUE_URL_PATHS` in https://github.com/home-assistant/frontend/blob/dev/src/components/ha-sidebar.ts
    private static let pathSortValue = [
        "energy": 1,
        "map": 2,
        "logbook": 3,
        "history": 4,
        // Moved into `config` in core 2026.2, kept for older servers
        "developer-tools": 9,
        "hassio": 10,
        "config": 11,
    ]

    /// Dashboards first, then everything else, mirroring `panelSorter` in
    /// https://github.com/home-assistant/frontend/blob/dev/src/components/ha-sidebar.ts
    private enum SortGroup: Int, Comparable {
        case overview
        case dashboard
        case builtInDashboard
        case other

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private static func sortGroup(of panel: HAPanel) -> SortGroup {
        if panel.path == overviewPath {
            return .overview
        } else if panel.component == "lovelace" {
            return .dashboard
        } else if builtInDashboardPaths.contains(panel.path) {
            return .builtInDashboard
        } else {
            return .other
        }
    }

    private static func isSortedBefore(_ lhs: HAPanel, _ rhs: HAPanel) -> Bool {
        let sortedByTitle = lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending

        let lhsGroup = sortGroup(of: lhs)
        let rhsGroup = sortGroup(of: rhs)
        guard lhsGroup == rhsGroup else {
            return lhsGroup < rhsGroup
        }
        guard lhsGroup == .other else {
            return sortedByTitle
        }

        let lhsSort = pathSortValue[lhs.path, default: -1]
        let rhsSort = pathSortValue[rhs.path, default: -1]

        if lhsSort == rhsSort {
            return sortedByTitle
        } else {
            return lhsSort < rhsSort
        }
    }
}

public extension HATypedRequest {
    static func panels() -> HATypedRequest<HAPanels> {
        .init(request: .init(type: "get_panels"))
    }
}

private struct HAPanelsCacheKey: HACacheKey {
    static func create(connection: HAConnection, data: [String: Any]) -> HACache<HAPanels> {
        HACache(
            connection: connection,
            populate: .init(
                request: .panels(),
                transform: { $0.incoming }
            ),
            subscribe: [
                HACacheSubscribeInfo(
                    subscription: .events("panels_updated"),
                    transform: { _ in .reissuePopulate }
                ),
            ]
        )
    }
}
