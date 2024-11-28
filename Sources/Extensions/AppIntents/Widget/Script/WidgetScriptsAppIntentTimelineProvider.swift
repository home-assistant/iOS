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
        let id: String
        let entityId: String
        let serverId: String
        let serverName: String
        let name: String
        let icon: String
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
        let placeholder: [WidgetScriptsEntry.ScriptServer] = Array(suggestions.flatMap { serverCollection in
            serverCollection.value.map { script in
                WidgetScriptsEntry.ScriptServer(
                    id: script.id,
                    entityId: script.entityId,
                    serverId: serverCollection.key.identifier.rawValue,
                    serverName: serverCollection.key.info.name,
                    name: script.name,
                    icon: script.icon ?? ""
                )
            }
        }.prefix(WidgetFamilySizes.sizeForPreview(for: context.family)))

        return .init(
            date: Date(),
            scripts: configuration.scripts?.compactMap({ intentScriptEntity in
                .init(
                    id: intentScriptEntity.id,
                    entityId: intentScriptEntity.entityId,
                    serverId: intentScriptEntity.serverId,
                    serverName: intentScriptEntity.serverName,
                    name: intentScriptEntity.displayString,
                    icon: intentScriptEntity.iconName
                )
            }) ?? placeholder,
            showServerName: showServerName(),
            showConfirmationDialog: configuration.showConfirmationDialog
        )
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<Entry> {
        let entry: Entry = await {
            if let configurationScripts = configuration.scripts?
                .prefix(WidgetFamilySizes.size(for: context.family)) {
                return Entry(date: Date(), scripts: configurationScripts.compactMap({ intentScriptEntity in
                    .init(
                        id: intentScriptEntity.id,
                        entityId: intentScriptEntity.entityId,
                        serverId: intentScriptEntity.serverId,
                        serverName: intentScriptEntity.serverName,
                        name: intentScriptEntity.displayString,
                        icon: intentScriptEntity.iconName
                    )
                }), showServerName: showServerName(), showConfirmationDialog: configuration.showConfirmationDialog)
            } else {
                let entries = await suggestions().flatMap { server, scripts in
                    scripts.map { script in
                        WidgetScriptsEntry.ScriptServer(
                            id: script.entityId,
                            entityId: script.entityId,
                            serverId: server.identifier.rawValue,
                            serverName: server.info.name,
                            name: script.name,
                            icon: script.icon ?? ""
                        )
                    }
                }.prefix(WidgetFamilySizes.sizeForPreview(for: context.family))
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
                id: "1",
                entityId: "1",
                serverId: "1",
                serverName: "Home",
                name: L10n.Widgets.Scripts.title,
                icon: ""
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
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                do {
                    let scripts: [HAAppEntity] = try Current.database.read { db in
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.script.rawValue)
                            .fetchAll(db)
                    }
                    entities[server] = scripts
                } catch {
                    Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
                }
            }
            continuation.resume(returning: entities)
        }
    }
}
