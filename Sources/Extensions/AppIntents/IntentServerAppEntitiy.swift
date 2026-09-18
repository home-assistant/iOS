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
                .filter { $0.getServer() != nil }
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
        Self.server(for: id)
    }

    func getInfo() -> ServerInfo? {
        getServer()?.info
    }

    /// Server identifiers are generated per installation, so a shortcut synced from another device
    /// through iCloud carries an identifier this device has never seen. When a single server is set
    /// up there is only one server that shortcut can mean, so resolve to it instead of failing.
    static func server(for rawIdentifier: String) -> Server? {
        if let server = Current.servers.server(for: .init(rawValue: rawIdentifier)) {
            return server
        }

        let allServers = Current.servers.all
        return allServers.count == 1 ? allServers.first : nil
    }
}
