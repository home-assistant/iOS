import HAKit

public extension HACachesContainer {
    var panels: HACache<HAPanels> { self[HAPanelsCacheKey.self] }
}

public struct HAPanel: HADataDecodable, Codable {
    public var componentName: String
    public var icon: String?
    public var title: String
    public var path: String

    public init(data: HAData) throws {
        self.componentName = try data.decode("component_name")
        self.icon = data.decode("icon", fallback: "mdi:view-dashboard")

        // TODO: do i really wanna copy these values from frontend repo?
        let defaultTitles = [
            "lovelace": "Overview",
            "energy": "Energy",
            "calendar": "Calendar",
            "config": "Configuration",
            "map": "Map",
            "logbook": "Logbook",
            "history": "History",
            "mailbox": "Mailbox",
            "shopping_list": "Shopping List",
            "developer_tools": "Developer Tools",
            "media_browser": "Media Browser",
            "profile": "Profile",
        ]

        if let title: String = try? data.decode("title") {
            self.title = defaultTitles[title] ?? title
        } else {
            self.title = defaultTitles[componentName] ?? componentName
        }
        self.path = try data.decode("url_path")
    }
}

public struct HAPanels: HADataDecodable, Codable {
    public var panelsByPath: [String: HAPanel]
    public var allPanels: [HAPanel]

    public init(data: HAData) throws {
        guard case let .dictionary(dictionary) = data else {
            throw HADataError.missingKey("root")
        }

        panelsByPath = try dictionary
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
        allPanels = panelsByPath.values.sorted(by: {
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
                )
            ]
        )
    }
}
