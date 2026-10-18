import AppIntents
import Foundation
import PromiseKit
@preconcurrency import Shared

@available(macOS 13.0, *)
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

    /// The entity id for a panel, which is how anything outside the query — the page the web view
    /// publishes as being on screen, for one — names a page without holding an `AppPanel`. Widgets
    /// created before this existed stored the same string, so the shape cannot change.
    static func makeId(serverId: String, panelPath: String) -> String {
        "\(serverId)-\(panelPath)"
    }
}

@available(macOS 13.0, *)
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
        PageAppEntity.makeId(serverId: server.identifier.rawValue, panelPath: panel.path)
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
