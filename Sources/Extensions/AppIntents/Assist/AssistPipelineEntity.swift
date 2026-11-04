import AppIntents
import Foundation
import Shared

@available(watchOS 9.4, *)
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
