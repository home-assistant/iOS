import HAKit

public extension HACachesContainer {
    var panels: HACache<HAPanels> { self[HAPanelsCacheKey.self] }
}

public struct HAPanel: HADataDecodable, Codable, Equatable {
    public var icon: String?
    public var title: String
    public var path: String
    public var component: String
    public var showInSidebar: Bool

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
        self.icon = data.decode("icon", fallback: fallbackIcon)
        self.path = try data.decode("url_path")

        let title: String = data.decode("title", fallback: component)

        let possibleFrontendKey: String
        if path == "lovelace" {
            possibleFrontendKey = "panel::states"
        } else {
            possibleFrontendKey = "panel::\(title)"
        }

        self.title = Current.localized.frontend(possibleFrontendKey) ?? title
    }
}

public struct HAPanels: HADataDecodable, Codable, Equatable {
    public var panelsByPath: [String: HAPanel]
    public var allPanels: [HAPanel]

    public init(panelsByPath: [String: HAPanel]) {
        self.panelsByPath = panelsByPath
        self.allPanels = panelsByPath.values.sorted(by: {
            let sortedByTitle = $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending

            switch ($0.component, $1.component) {
            case ("lovelace", "lovelace"):
                return sortedByTitle
            case ("lovelace", _):
                return true
            case (_, "lovelace"):
                return false
            default:
                // from the frontend as of 9a928259549b255ae79fbdb412538109e31d62d2 2021-07-28
                // https://github.com/home-assistant/frontend/blob/b26c44b2/src/components/ha-sidebar.ts#L55-L63
                let pathSortValue = [
                    "energy": 1,
                    "map": 2,
                    "logbook": 3,
                    "history": 4,
                    "developer-tools": 9,
                    "hassio": 10,
                    "config": 11,
                ]

                let sort0 = pathSortValue[$0.path, default: -1]
                let sort1 = pathSortValue[$1.path, default: -1]

                if sort0 == sort1 {
                    return sortedByTitle
                } else {
                    return sort0 < sort1
                }
            }
        })
    }

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data else {
            throw HADataError.missingKey("root")
        }

        self.init(
            panelsByPath: try dictionary
                .compactMapKeys {
                    if $0.hasPrefix("_") {
                        return nil
                    } else {
                        return $0
                    }
                }
                .mapValues {
                    try HAPanel(data: .init(value: $0))
                }
                // non-show_in_sidebar dashboards have badly-named titles
                .filter(\.value.showInSidebar)
        )
    }
}

public extension HATypedRequest {
    static func panels() -> HATypedRequest<HAPanels> {
        .init(request: .init(type: "get_panels"))
    }
}

private struct HAPanelsCacheKey: HACacheKey {
    static func create(connection: HAConnection) -> HACache<HAPanels> {
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
