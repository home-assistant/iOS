import PromiseKit
import Shared
import SwiftUI
import WidgetKit

struct WidgetAssistEntry: TimelineEntry {
    var date = Date()
    var server: IntentServer?
    var pipeline: IntentAssistPipeline?
    var withVoice = true
}

struct WidgetAssistProvider: IntentTimelineProvider {
    typealias Intent = AssistInAppIntent
    typealias Entry = WidgetAssistEntry

    @Environment(\.diskCache) var diskCache: DiskCache

    func placeholder(in context: Context) -> WidgetAssistEntry {
        .init()
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        guard let server = configuration.server, let pipeline = configuration.pipeline else {
            completion(.init())
            return
        }
        let entry = WidgetAssistEntry(
            server: configuration.server,
            pipeline: configuration.pipeline,
            withVoice: Bool(truncating: configuration.withVoice ?? 1)
        )
        completion(entry)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [
            WidgetAssistEntry(
                server: configuration.server,
                pipeline: configuration.pipeline,
                withVoice: Bool(truncating: configuration.withVoice ?? 1)
            ),
        ], policy: .never))
    }
}
