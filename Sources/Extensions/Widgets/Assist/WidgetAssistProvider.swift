import AppIntents
import Shared
import SwiftUI
import WidgetKit

struct WidgetAssistEntry: TimelineEntry {
    var date = Date()
    var pipeline: AssistPipelineEntity?
    var withVoice = true
}

@available(iOS 17.0, *)
struct WidgetAssistAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Intent = WidgetAssistAppIntent
    typealias Entry = WidgetAssistEntry

    private var defaultEntry: WidgetAssistEntry {
        let pipeline = Current.servers.all.first
            .map { AssistPipelineEntity.preferred(serverId: $0.identifier.rawValue) }
        return WidgetAssistEntry(pipeline: pipeline, withVoice: true)
    }

    func placeholder(in context: Context) -> WidgetAssistEntry {
        .init()
    }

    func snapshot(for configuration: WidgetAssistAppIntent, in context: Context) async -> WidgetAssistEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: WidgetAssistAppIntent, in context: Context) async -> Timeline<Entry> {
        .init(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: WidgetAssistAppIntent) -> WidgetAssistEntry {
        WidgetAssistEntry(
            pipeline: configuration.pipeline ?? defaultEntry.pipeline,
            withVoice: configuration.withVoice
        )
    }
}
