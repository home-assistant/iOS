import AppIntents
import Foundation
import Shared

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct IntentServerAppEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "MaterialDesignIcons")

    struct IntentServerAppEntityQuery: EntityQuery, EntityStringQuery {
        func entities(for identifiers: [IntentServerAppEntity.ID]) async throws -> [IntentServerAppEntity] {
            getServerEntities().filter { identifiers.contains($0.id) }
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
        getServer()?.info
    }
}
