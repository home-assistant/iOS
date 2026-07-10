import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlAssistItem {
    let pipeline: AssistPipelineEntity
    let displayText: String?
}

@available(iOS 18, *)
struct ControlAssistValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlAssistConfiguration) async throws -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    func placeholder(for configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    func previewValue(configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    private func placeholder() -> AssistPipelineEntity {
        AssistPipelineEntity(id: "", serverId: "", name: L10n.Widgets.Controls.Assist.Pipeline.placeholder)
    }
}

@available(iOS 18.0, *)
struct ControlAssistConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Assist"

    @Parameter(
        title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline")
    )
    var pipeline: AssistPipelineEntity?
    @Parameter(
        title: .init("app_intents.display_text.title", defaultValue: "Display Text")
    )
    var displayText: String?
}

struct AssistPipelineEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Assist Pipeline")
    static let defaultQuery = AssistPipelineEntityQuery()

    /// Per-server "Preferred" id. Encoding the server id keeps each server's entry uniquely addressable
    /// (the entity `id` is what App Intents persists), and real pipeline ids never use this prefix.
    static let preferredIdPrefix = "preferred-pipeline:"

    let id: String
    let serverId: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }

    static func preferred(serverId: String) -> AssistPipelineEntity {
        .init(
            id: preferredIdPrefix + serverId,
            serverId: serverId,
            name: L10n.AppIntents.Assist.PreferredPipeline.title
        )
    }

    /// Legacy selections were stored with an empty id, so those count as preferred too.
    var isPreferred: Bool {
        id.isEmpty || id.hasPrefix(Self.preferredIdPrefix)
    }

    var pipelineId: String? {
        isPreferred ? nil : id
    }
}

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
            Current.Log.error("Failed to fetch assist pipelines for ControlAssist: \(error.localizedDescription)")
            throw error
        }
    }
}
