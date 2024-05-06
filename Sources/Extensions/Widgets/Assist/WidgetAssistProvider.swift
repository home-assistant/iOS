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

    private let defaultEntry = {
        var intentServer: IntentServer? = {
            if let server = Current.servers.all.first {
                return IntentServer(server: server)
            } else {
                return nil
            }
        }()
        return WidgetAssistEntry(
            server: intentServer,
            pipeline: IntentAssistPipeline(
                identifier: "0",
                display: L10n.AppIntents.Assist.PreferredPipeline.title
            ),
            withVoice: .init(true)
        )
    }()

    func placeholder(in context: Context) -> WidgetAssistEntry {
        .init()
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (Entry) -> Void) {
        guard let server = configuration.server, let pipeline = configuration.pipeline else {
            completion(defaultEntry)
            return
        }
        let entry = WidgetAssistEntry(
            server: server,
            pipeline: pipeline,
            withVoice: Bool(truncating: configuration.withVoice ?? 1)
        )
        completion(entry)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        completion(.init(entries: [
            WidgetAssistEntry(
                server: configuration.server ?? defaultEntry.server,
                pipeline: configuration.pipeline ?? defaultEntry.pipeline,
                withVoice: Bool(truncating: configuration.withVoice ?? 1)
            ),
        ], policy: .never))
    }
}
