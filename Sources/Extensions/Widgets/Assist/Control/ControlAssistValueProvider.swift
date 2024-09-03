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
        title: "Pipeline"
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
            pipelines.compactMap { pipeline in
                AssistPipelineEntity(id: pipeline.id, serverId: key.identifier.rawValue, name: pipeline.name)
            }
        }
        return entities.filter { entity in
            identifiers.contains(entity.id)
        }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<AssistPipelineEntity> {
        let pipelines = try await pipelines()
        return .init(sections: pipelines.map({ server, pipelines in
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
        }))
    }

    func suggestedEntities() async throws -> IntentItemCollection<AssistPipelineEntity> {
        let pipelines = try await pipelines()
        return .init(sections: pipelines.map({ server, pipelines in
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
        }))
    }

    private func pipelines() async throws -> [Server: [Pipeline]] {
        await withCheckedContinuation { continuation in
            var pipelines: [Server: [Pipeline]] = [:]
            var fetchedServersCount = 0
            for server in Current.servers.all {
                let assistService = AssistService(server: server)
                assistService.fetchPipelines { response in
                    pipelines[server] = response?.pipelines ?? []

                    fetchedServersCount += 1
                    if fetchedServersCount == Current.servers.all.count {
                        continuation.resume(returning: pipelines)
                    }
                }
            }
        }
    }
}
