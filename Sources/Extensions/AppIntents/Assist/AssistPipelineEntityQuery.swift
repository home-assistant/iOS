import AppIntents
import Foundation
import Shared

@available(watchOS 9.4, *)
struct AssistPipelineEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [AssistPipelineEntity] {
        let pipelinesPerServer = try await pipelines()
        return identifiers.compactMap { identifier -> AssistPipelineEntity? in
            if identifier.hasPrefix(AssistPipelineEntity.preferredIdPrefix) {
                return .preferred(serverId: String(identifier.dropFirst(AssistPipelineEntity.preferredIdPrefix.count)))
            }
            if identifier.isEmpty {
                // Legacy "Preferred" carried no server; fall back to the first (single-server upgraders).
                guard let server = Current.servers.all.first else { return nil }
                return .preferred(serverId: server.identifier.rawValue)
            }
            for (server, pipelines) in pipelinesPerServer {
                if let pipeline = pipelines.first(where: { $0.id == identifier }) {
                    return .init(id: pipeline.id, serverId: server.identifier.rawValue, name: pipeline.name)
                }
            }
            return nil
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<AssistPipelineEntity> {
        let pipelines = try await pipelines()
        var sections = pipelines.map({ server, pipelines in
            IntentItemSection<AssistPipelineEntity>(
                .init(stringLiteral: server.info.name),
                items: entities(forServer: server, pipelines: pipelines)
                    .filter { $0.name.contains(string) }
                    .map { .init($0) }
            )
        })
        sections.append(.init(
            .init(stringLiteral: L10n.helpLabel),
            items: [.init(.init(
                id: "-1",
                serverId: "",
                name: L10n.AppIntents.Assist.RefreshWarning.title
            ))]
        ))
        return .init(sections: sections)
    }

    func suggestedEntities() async throws -> IntentItemCollection<AssistPipelineEntity> {
        let pipelines = try await pipelines()
        var sections = pipelines.map({ server, pipelines in
            IntentItemSection<AssistPipelineEntity>(
                .init(stringLiteral: server.info.name),
                items: entities(forServer: server, pipelines: pipelines).map { .init($0) }
            )
        })
        sections.append(.init(
            .init(stringLiteral: L10n.helpLabel),
            items: [.init(.init(id: "-1", serverId: "", name: L10n.AppIntents.Assist.RefreshWarning.title))]
        ))
        return .init(sections: sections)
    }

    func defaultResult() async -> AssistPipelineEntity? {
        guard let server = Current.servers.all.first else { return nil }
        return .preferred(serverId: server.identifier.rawValue)
    }

    private func entities(forServer server: Server, pipelines: [Pipeline]) -> [AssistPipelineEntity] {
        [.preferred(serverId: server.identifier.rawValue)] + pipelines.map { pipeline in
            AssistPipelineEntity(id: pipeline.id, serverId: server.identifier.rawValue, name: pipeline.name)
        }
    }

    /// Pipelines are read from the local mirror both iOS and watchOS keep in GRDB, so the picker
    /// works without a server round trip on either platform.
    private func pipelines() async throws -> [Server: [Pipeline]] {
        do {
            var result: [Server: [Pipeline]] = [:]
            let pipelines = try await Current.database().read { db in
                try AssistPipelines.fetchAll(db)
            }
            pipelines.forEach { assistPipeline in
                guard let server = Current.servers.all
                    .first(where: { $0.identifier.rawValue == assistPipeline.serverId }),
                    !assistPipeline.pipelines.isEmpty else { return }
                result[server] = assistPipeline.pipelines
            }
            return result
        } catch {
            Current.Log.error("Failed to fetch assist pipelines: \(error.localizedDescription)")
            throw error
        }
    }
}
