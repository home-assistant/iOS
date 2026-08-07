import Shared
import SwiftUI
import WidgetKit

struct WidgetAssistEntry: TimelineEntry {
    var date = Date()
    var pipeline: AssistPipelineEntity?
    var withVoice = true

    var widgetURL: URL {
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

    private var defaultEntry: WidgetAssistEntry {
        WidgetAssistEntry(
            pipeline: Current.servers.all.first.map { .preferred(serverId: $0.identifier.rawValue) },
            withVoice: true
        )
    }

    func placeholder(in context: Context) -> WidgetAssistEntry {
        .init()
    }

    /// Mocked entry for the widget gallery — see `WidgetPreviewSample`.
    private var previewEntry: WidgetAssistEntry {
        WidgetAssistEntry(
            pipeline: .preferred(serverId: WidgetPreviewSample.serverId),
            withVoice: true
        )
    }

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        // `context.isPreview` is WidgetKit's hook for the gallery, which renders with an
        // unconfigured intent. Serve the mock there so the picker reads nothing.
        if context.isPreview {
            return previewEntry
        }
        guard let pipeline = configuration.pipeline else {
            return defaultEntry
        }
        return WidgetAssistEntry(pipeline: pipeline, withVoice: configuration.withVoice)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        if context.isPreview {
            return Timeline(entries: [previewEntry], policy: .never)
        }
        return Timeline(entries: [
            WidgetAssistEntry(
                pipeline: configuration.pipeline ?? defaultEntry.pipeline,
                withVoice: configuration.withVoice
            ),
        ], policy: .never)
    }
}
