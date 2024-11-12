import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlAssistItem {
    let pipeline: AssistPipelineEntity
}

@available(iOS 18, *)
struct ControlAssistValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlAssistConfiguration) async throws -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder())
    }

    func placeholder(for configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder())
    }

    func previewValue(configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder())
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
}

@available(iOS 16.4, *)
struct AssistPipelineEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Assist Pipeline")
    static let defaultQuery = AssistPipelineEntityQuery()

    let id: String
    let serverId: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        .init(title: .init(stringLiteral: name))
    }
}

@available(iOS 16.4, *)
struct AssistPipelineEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [AssistPipelineEntity] {
        let pipelinesPerServer = try await pipelines()
        let entities = pipelinesPerServer.flatMap { key, pipelines in
            pipelines.filter({ identifiers.contains($0.id) }).compactMap { pipeline in
                AssistPipelineEntity(id: pipeline.id, serverId: key.identifier.rawValue, name: pipeline.name)
            }
        }

        return entities.filter { entity in
            identifiers.contains(entity.id)
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<AssistPipelineEntity> {
        let pipelines = try await pipelines()
        var sections = pipelines.map({ server, pipelines in
            IntentItemSection<AssistPipelineEntity>(
                .init(stringLiteral: server.info.name),
                items: pipelines.filter { $0.name.contains(string) }.map({ pipeline in
                    .init(AssistPipelineEntity(
                        id: pipeline.id,
                        serverId: server.identifier.rawValue,
                        name: pipeline.name
                    ))
                })
            )
        })
        sections.append(.init(
            .init(stringLiteral: L10n.helpLabel),
            items: [.init(.init(
                id: "",
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
                items: pipelines.map({ pipeline in
                    .init(AssistPipelineEntity(
                        id: pipeline.id,
                        serverId: server.identifier.rawValue,
                        name: pipeline.name
                    ))
                })
            )
        })
        sections.append(.init(
            .init(stringLiteral: L10n.helpLabel),
            items: [.init(.init(id: "-1", serverId: "", name: L10n.AppIntents.Assist.RefreshWarning.title))]
        ))
        return .init(sections: sections)
    }

    private func pipelines() async throws -> [Server: [Pipeline]] {
        do {
            var result: [Server: [Pipeline]] = [:]
            let pipelines = try await Current.database.read { db in
                try AssistPipelines.fetchAll(db)
            }
            pipelines.forEach { assistPipeline in
                guard let server = Current.servers.all
                    .first(where: { $0.identifier.rawValue == assistPipeline.serverId }) else { return }
                result[server] = assistPipeline.pipelines

                // Empty id indicates use of preferred pipeline
                result[server]?.insert(.init(id: "", name: L10n.AppIntents.Assist.PreferredPipeline.title), at: 0)
            }
            return result
        } catch {
            Current.Log.error("Failed to fetch assist pipelines for ControlAssist: \(error.localizedDescription)")
            throw error
        }
    }
}
