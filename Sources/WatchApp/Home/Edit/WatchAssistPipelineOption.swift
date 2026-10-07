import Foundation
import Shared

/// One choice in the watch's Assist pickers: a server's pipeline, or that server's "Preferred"
/// pipeline (empty id, resolved by the server at run time). Read from the mirrored `AssistPipelines`
/// table, so the add flow works with the iPhone out of range.
struct WatchAssistPipelineOption: Identifiable, Hashable {
    let serverId: String
    let serverName: String
    let pipelineId: String
    let name: String

    var id: String { "\(serverId)|\(pipelineId)" }

    /// True for the entry that lets the server pick — it can't reuse a pipeline's identity.
    var isPreferred: Bool { pipelineId.isEmpty }

    /// Every mirrored server's pipelines, each group preceded by its "Preferred" entry. Servers
    /// without any cached pipeline are omitted.
    static func all() -> [WatchAssistPipelineOption] {
        let configs = ((try? AssistPipelines.config()) ?? nil) ?? []
        return configs.flatMap { config -> [WatchAssistPipelineOption] in
            guard !config.pipelines.isEmpty else { return [] }
            let serverName = Current.servers.server(forServerIdentifier: config.serverId)?.info.name ?? config.serverId
            let preferred = WatchAssistPipelineOption(
                serverId: config.serverId,
                serverName: serverName,
                pipelineId: "",
                name: L10n.Watch.Config.Assist.preferred
            )
            return [preferred] + config.pipelines.map { pipeline in
                WatchAssistPipelineOption(
                    serverId: config.serverId,
                    serverName: serverName,
                    pipelineId: pipeline.id,
                    name: pipeline.name
                )
            }
        }
    }

    /// The item this option adds to the configuration. "Preferred" can't key its identity on the
    /// empty pipeline id, so it gets a UUID and carries the marker in `assistPipelineId` — the same
    /// rule the iPhone and CarPlay add flows follow.
    func makePipelineItem() -> MagicItem {
        MagicItem(
            id: isPreferred ? UUID().uuidString : pipelineId,
            serverId: serverId,
            type: .assistPipeline,
            customization: .init(iconColor: MagicItem.defaultAssistIconColorHex),
            assistPipelineId: isPreferred ? "" : nil
        )
    }
}
