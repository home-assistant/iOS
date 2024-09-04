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
                PageAppEntity(id: id(for: panel, server: server), panel: panel, serverId: server.identifier.rawValue)
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
                    panel: panel,
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
                    panel: panel,
                    serverId: server.identifier.rawValue
                )
            }))
        }))
    }

    func id(for panel: HAPanel, server: Server) -> String {
        "\(server.identifier.rawValue)-\(panel.path)"
    }

    private func panels() async throws -> [Server: [HAPanel]] {
        await withCheckedContinuation { continuation in
            var panelsPerServer: [Server: [HAPanel]] = [:]
            var finishedPipesCount = 0
            for server in Current.servers.all {
                (
                    Current.diskCache
                        .value(
                            for: OpenPageIntentHandler
                                .cacheKey(serverIdentifier: server.identifier.rawValue)
                        ) as Promise<HAPanels>
                ).pipe { result in
                    switch result {
                    case let .fulfilled(panels):
                        panelsPerServer[server] = panels.allPanels
                    case let .rejected(error):
                        Current.Log.error("Failed to retrieve HAPanels, error: \(error.localizedDescription)")
                    }
                    finishedPipesCount += 1

                    if finishedPipesCount == Current.servers.all.count {
                        continuation.resume(returning: panelsPerServer)
                    }
                }
            }
        }
    }
}
