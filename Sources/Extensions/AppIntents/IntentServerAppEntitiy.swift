import AppIntents
import Foundation
import Shared

@available(macOS 13.0, tvOS 16.0, *)
struct IntentServerAppEntity: AppEntity, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "MaterialDesignIcons")

    struct IntentServerAppEntityQuery: EntityQuery, EntityStringQuery {
        /// Reconstructs each requested identifier through `getServer()`, keeping the original id so
        /// an iCloud-synced shortcut does not rewrite the other device's server reference.
        func entities(for identifiers: [IntentServerAppEntity.ID]) async throws -> [IntentServerAppEntity] {
            var seen = Set<IntentServerAppEntity.ID>()
            return identifiers.compactMap { identifier in
                guard seen.insert(identifier).inserted else { return nil }
                let entity = IntentServerAppEntity(identifier: .init(rawValue: identifier))
                guard entity.getServer() != nil else { return nil }
                return entity
            }
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

    /// The locally configured server this entity refers to.
    ///
    /// An exact identifier match always wins. A nonempty unknown id is resolved only when this
    /// device has exactly one server and is not waiting to restore mirrored servers — the
    /// single-server shortcut-sync case, where the other installation's opaque id cannot be proven
    /// to name a different instance. Empty ids, an empty or ambiguous registry, and a pending
    /// mirror restore return nil rather than picking an arbitrary server.
    func getServer() -> Server? {
        let servers = Current.servers
        if let exact = servers.server(for: .init(rawValue: id)) {
            return exact
        }

        guard id.isEmpty == false, servers.isMirrorRestorePending == false, servers.all.count == 1 else {
            return nil
        }

        return servers.all.first
    }

    func getInfo() -> ServerInfo? {
        getServer()?.info
    }
}
