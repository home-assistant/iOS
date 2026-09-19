import AppIntents
import Foundation
import Shared

@available(macOS 13.0, tvOS 16.0, *)
struct IntentServerAppEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "MaterialDesignIcons")

    struct IntentServerAppEntityQuery: EntityQuery, EntityStringQuery {
        func entities(for identifiers: [IntentServerAppEntity.ID]) async throws -> [IntentServerAppEntity] {
            // Keep the persisted identifier rather than the local server's one, so a shortcut synced
            // between devices keeps working on both instead of being fixed on one and broken on the other.
            identifiers
                .map { IntentServerAppEntity(identifier: .init(rawValue: $0)) }
                .filter { $0.shortcutServer() != nil }
        }

        func entities(matching string: String) async throws -> [IntentServerAppEntity] {
            getServerEntities().filter { $0.getInfo()?.remoteName.contains(string) ?? false }
        }

        func suggestedEntities() async throws -> [IntentServerAppEntity] {
            getServerEntities()
        }

        private func getServerEntities() -> [IntentServerAppEntity] {
            Current.servers.all.map { IntentServerAppEntity(from: $0) }
        }

        func defaultResult() async -> IntentServerAppEntity? {
            let server = Current.servers.all.first
            if server == nil {
                return nil
            } else {
                return IntentServerAppEntity(from: server!)
            }
        }
    }

    static let defaultQuery = IntentServerAppEntityQuery()

    var id: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: .init(stringLiteral: getInfo()?.name ?? "Unknown")
        )
    }

    init(identifier: Identifier<Server>) {
        self.id = identifier.rawValue
    }

    init(from server: Server) {
        self.init(identifier: server.identifier)
    }

    func getServer() -> Server? {
        Current.servers.server(for: .init(rawValue: id))
    }

    func getInfo() -> ServerInfo? {
        shortcutServer()?.info
    }

    /// The server a shortcut means, resolving an identifier this installation never issued to the
    /// only server set up.
    ///
    /// Shortcuts sync between devices through iCloud while server identifiers are generated per
    /// installation, so the synced copy names a server the other device has never seen. With a
    /// single server there is only one server it can mean.
    ///
    /// Widgets stay on the strict `getServer()`: one configured for a server that is gone shows
    /// nothing, rather than quietly switching to another server's data.
    func shortcutServer() -> Server? {
        Self.shortcutServer(for: id)
    }

    static func shortcutServer(for rawIdentifier: String) -> Server? {
        if let server = Current.servers.server(for: .init(rawValue: rawIdentifier)) {
            return server
        }

        let allServers = Current.servers.all
        return allServers.count == 1 ? allServers.first : nil
    }
}
