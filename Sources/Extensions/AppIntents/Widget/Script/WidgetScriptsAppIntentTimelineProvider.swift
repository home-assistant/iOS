import AppIntents
import PromiseKit
import RealmSwift
import Shared
import WidgetKit

struct WidgetScriptsEntry: TimelineEntry {
    let date: Date
    let scripts: [ScriptServer]

    struct ScriptServer {
        let script: HAScript
        let serverId: String
    }
}

@available(iOS 17, *)
struct WidgetScriptsAppIntentTimelineProvider: AppIntentTimelineProvider {
    typealias Entry = WidgetScriptsEntry
    typealias Intent = WidgetScriptsAppIntent

    static var expiration: Measurement<UnitDuration> {
        .init(value: 24, unit: .hours)
    }

    func snapshot(for configuration: WidgetScriptsAppIntent, in context: Context) async -> Entry {
        .init(date: Date(), scripts: configuration.scripts?.compactMap({ intentScriptEntity in
            .init(
                script: .init(id: intentScriptEntity.id, name: intentScriptEntity.displayString, iconName: intentScriptEntity.iconName),
                serverId: intentScriptEntity.serverId
            )
        }) ?? [])
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry = Entry(date: Date(), scripts: configuration.scripts?.compactMap({ intentScriptEntry in
                .init(
                    script: .init(id: intentScriptEntry.id, name: intentScriptEntry.displayString, iconName: intentScriptEntry.iconName),
                    serverId: intentScriptEntry.serverId
                )
        }) ?? [])
        return .init(
            entries: [entry],
            policy: .after(
                Current.date()
                    .addingTimeInterval(Self.expiration.converted(to: .seconds).value)
            )
        )
    }

    func placeholder(in context: Context) -> Entry {
        .init(date: Date(), scripts: [.init(script: .init(id: "1", name: "Run Script", iconName: nil), serverId: "1")])
    }
}
