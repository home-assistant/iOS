import HAKit

public extension HACachesContainer {
    var panels: HACache<HAPanels> { self[HAPanelsCacheKey.self] }
}

public struct HAPanel: HADataDecodable, Codable {
    public var icon: String?
    public var title: String
    public var path: String

    public init(data: HAData) throws {
        let component: String = try data.decode("component_name")
        let fallbackIcon: String? = { () -> String? in
            switch component {
            case "profile": return "mdi:account"
            case "lovelace": return "mdi:view-dashboard"
            default: return nil
            }
        }()

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

public struct HAPanels: HADataDecodable, Codable {
    public var panelsByPath: [String: HAPanel]
    public var allPanels: [HAPanel]

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data else {
            throw HADataError.missingKey("root")
        }

        self.panelsByPath = try dictionary
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
        self.allPanels = panelsByPath.values.sorted(by: {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        })
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
