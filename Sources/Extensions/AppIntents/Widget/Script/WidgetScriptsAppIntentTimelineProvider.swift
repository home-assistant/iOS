import AppIntents
import GRDB
import PromiseKit
import RealmSwift
import Shared
import WidgetKit

struct WidgetScriptsEntry: TimelineEntry {
    let date: Date
    let scripts: [ScriptServer]
    let showServerName: Bool
    let showConfirmationDialog: Bool

    struct ScriptServer {
        let script: HAAppEntity
        let serverId: String
        let serverName: String
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
        let suggestions = await suggestions()
        let placeholder: [WidgetScriptsEntry.ScriptServer] = await Array(suggestions.flatMap { serverCollection in
            serverCollection.value.map { script in
                WidgetScriptsEntry.ScriptServer(
                    script: script,
                    serverId: serverCollection.key.identifier.rawValue,
                    serverName: serverCollection.key.info.name
                )
            }
        }.prefix(WidgetBasicContainerView.maximumCount(family: context.family)))

        return .init(
            date: Date(),
            scripts: configuration.scripts?.compactMap({ intentScriptEntity in
                .init(
                    script: .init(
                        id: "\(intentScriptEntity.serverId)-\(intentScriptEntity.id)",
                        entityId: intentScriptEntity.id,
                        serverId: intentScriptEntity.serverId,
                        domain: Domain.script.rawValue,
                        name: intentScriptEntity.displayString,
                        icon: intentScriptEntity.iconName
                    ),
                    serverId: intentScriptEntity.serverId,
                    serverName: intentScriptEntity.serverName
                )
            }) ?? placeholder,
            showServerName: showServerName(),
            showConfirmationDialog: configuration.showConfirmationDialog
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry: Entry = await {
            if let configurationScripts = await configuration.scripts?
                .prefix(WidgetBasicContainerView.maximumCount(family: context.family)) {
                return Entry(date: Date(), scripts: configurationScripts.compactMap({ intentScriptEntity in
                    .init(
                        script: .init(
                            id: "\(intentScriptEntity.serverId)-\(intentScriptEntity.id)",
                            entityId: intentScriptEntity.id,
                            serverId: intentScriptEntity.serverId,
                            domain: Domain.script.rawValue,
                            name: intentScriptEntity.displayString,
                            icon: intentScriptEntity.iconName
                        ),
                        serverId: intentScriptEntity.serverId,
                        serverName: intentScriptEntity.serverName
                    )
                }), showServerName: showServerName(), showConfirmationDialog: configuration.showConfirmationDialog)
            } else {
                let entries = await suggestions().flatMap { server, scripts in
                    scripts.map { script in
                        WidgetScriptsEntry.ScriptServer(
                            script: script,
                            serverId: server.identifier.rawValue,
                            serverName: server.info.name
                        )
                    }
                }.prefix(WidgetBasicContainerView.maximumCount(family: context.family))
                return Entry(
                    date: Date(),
                    scripts: Array(entries),
                    showServerName: showServerName(),
                    showConfirmationDialog: configuration.showConfirmationDialog
                )
            }
        }()
        return .init(
            entries: [entry],
            policy: .after(
                Current.date()
                    .addingTimeInterval(Self.expiration.converted(to: .seconds).value)
            )
        )
    }

    func placeholder(in context: Context) -> Entry {
        .init(
            date: Date(),
            scripts: [.init(
                script: .init(
                    id: "1",
                    entityId: "1",
                    serverId: "1",
                    domain: Domain.script.rawValue,
                    name: L10n.Widgets.Scripts.title,
                    icon: nil
                ),
                serverId: "1",
                serverName: "Home"
            )],
            showServerName: true, showConfirmationDialog: true
        )
    }

    private func showServerName() -> Bool {
        Current.servers.all.count > 1
    }

    private func suggestions() async -> [Server: [HAAppEntity]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [HAAppEntity]] = [:]
            var serverCheckedCount = 0
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                do {
                    let scripts: [HAAppEntity] = try Current.appGRDB().read { db in
                        try HAAppEntity.filter(Column("serverId") == server.identifier.rawValue)
                            .filter(Column("domain") == Domain.script.rawValue).fetchAll(db)
                    }
                    entities[server] = scripts
                } catch {
                    Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
                }
                serverCheckedCount += 1
                if serverCheckedCount == Current.servers.all.count {
                    continuation.resume(returning: entities)
                }
            }
        }
    }
}
