import Shared
import SwiftUI
import WidgetKit

struct WidgetAssistEntry: TimelineEntry {
    var date = Date()
    var pipelines: [AssistPipelineEntity] = []
    var withVoice = true
    /// True for the gallery sample, whose pipelines belong to no real server — the view uses this
    /// to skip the server-name subtitle rather than resolving one that doesn't apply.
    var isPreview = false

    /// Whole-widget destination used by the families that show a single pipeline
    /// (`systemSmall`, `accessoryCircular`).
    var widgetURL: URL {
        Self.widgetURL(for: pipelines.first, withVoice: withVoice)
    }

    static func widgetURL(for pipeline: AssistPipelineEntity?, withVoice: Bool) -> URL {
        let serverId = pipeline?.serverId.isEmpty == false
            ? pipeline?.serverId
            : Current.servers.all.first?.identifier.rawValue
        return AppConstants.assistDeeplinkURL(
            serverId: serverId ?? "",
            pipelineId: pipeline?.pipelineId ?? "",
            startListening: withVoice
        ) ?? AppConstants.deeplinkURL
    }
}

@available(iOS 17.0, *)
struct WidgetAssistProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetAssistEntry
    typealias Intent = WidgetAssistAppIntent

    func placeholder(in context: Context) -> WidgetAssistEntry {
        .init()
    }

    /// Mocked entry for the widget gallery — see `WidgetPreviewSample`. "Home Assistant" is the
    /// server's default pipeline name (a brand name, not translated), giving the medium family a
    /// second tile without a preview-only string.
    private func previewEntry(in context: Context) -> WidgetAssistEntry {
        let samplePipelines: [AssistPipelineEntity] = [
            .preferred(serverId: WidgetPreviewSample.serverId),
            .init(
                id: "sample-pipeline",
                serverId: WidgetPreviewSample.serverId,
                name: "Home Assistant"
            ),
        ]
        return WidgetAssistEntry(
            pipelines: Array(samplePipelines.prefix(WidgetFamilySizes.size(for: context.family))),
            withVoice: true,
            isPreview: true
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        // `context.isPreview` is WidgetKit's hook for the gallery, which renders with an
        // unconfigured intent. Serve the mock there so the picker reads nothing.
        if context.isPreview {
            return previewEntry(in: context)
        }
        return entry(for: configuration, in: context)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        if context.isPreview {
            return Timeline(entries: [previewEntry(in: context)], policy: .never)
        }
        return Timeline(entries: [entry(for: configuration, in: context)], policy: .never)
    }

    private func entry(for configuration: Intent, in context: Context) -> Entry {
        // Widgets configured before multi-pipeline support carry their selection in the
        // legacy single `pipeline` parameter.
        let configured = configuration.pipelines
            ?? configuration.pipeline.map { [$0] }
            ?? []
        let pipelines = configured.isEmpty ? defaultPipelines : configured
        return WidgetAssistEntry(
            pipelines: Array(pipelines.prefix(WidgetFamilySizes.size(for: context.family))),
            withVoice: configuration.withVoice
        )
    }

    private var defaultPipelines: [AssistPipelineEntity] {
        Current.servers.all.first.map { [.preferred(serverId: $0.identifier.rawValue)] } ?? []
    }
}
