import AppIntents
import Foundation
import PromiseKit
@preconcurrency import Shared

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct PageAppEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Page")

    static let defaultQuery = PageAppEntityQuery()

    var id: String
    var panel: HAPanel
    var serverId: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(panel.title)")
    }

    init(id: String, panel: HAPanel, serverId: String) {
        self.id = id
        self.panel = panel
        self.serverId = serverId
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct PageAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PageAppEntity] {
        try await panels().flatMap { server, panels in
            panels.filter({ panel in
                identifiers.contains(id(for: panel, server: server))
            }).compactMap { panel in
                PageAppEntity(
                    id: id(for: panel, server: server),
                    panel: toHAPanel(appPanel: panel),
                    serverId: server.identifier.rawValue
                )
            }
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<PageAppEntity> {
        try await .init(sections: panels().map({ server, panels in
            .init(.init(stringLiteral: server.info.name), items: panels.filter({ panel in
                panel.title.lowercased().contains(string.lowercased())
            }).map({ panel in
                PageAppEntity(
                    id: id(for: panel, server: server),
                    panel: toHAPanel(appPanel: panel),
                    serverId: server.identifier.rawValue
                )
            }))
        }))
    }

    func suggestedEntities() async throws -> IntentItemCollection<PageAppEntity> {
        try await .init(sections: panels().map({ server, panels in
            .init(.init(stringLiteral: server.info.name), items: panels.map({ panel in
                PageAppEntity(
                    id: id(for: panel, server: server),
                    panel: toHAPanel(appPanel: panel),
                    serverId: server.identifier.rawValue
                )
            }))
        }))
    }

    func id(for panel: AppPanel, server: Server) -> String {
        "\(server.identifier.rawValue)-\(panel.path)"
    }

    // Since AppPanels came afterwards we need to keep the same
    // object as before to not break previously created widgets
    private func toHAPanel(appPanel: AppPanel) -> HAPanel {
        .init(
            icon: appPanel.icon,
            title: appPanel.title,
            path: appPanel.path,
            component: appPanel.component,
            showInSidebar: appPanel.showInSidebar
        )
    }

    private func panels() async throws -> [Server: [AppPanel]] {
        try AppPanel.panelsPerServer()
    }
}
