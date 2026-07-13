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

    func snapshot(for configuration: Intent, in context: Context) async -> Entry {
        guard let pipeline = configuration.pipeline else {
            return defaultEntry
        }
        return WidgetAssistEntry(pipeline: pipeline, withVoice: configuration.withVoice)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        Timeline(entries: [
            WidgetAssistEntry(
                pipeline: configuration.pipeline ?? defaultEntry.pipeline,
                withVoice: configuration.withVoice
            ),
        ], policy: .never)
    }
}
