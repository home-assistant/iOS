import AppIntents
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
        let script: HAScript
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
        let placeholder: [WidgetScriptsEntry.ScriptServer] = Array(suggestions.flatMap { serverCollection in
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
                        id: intentScriptEntity.id,
                        name: intentScriptEntity.displayString,
                        iconName: intentScriptEntity.iconName
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
            if let configurationScripts = configuration.scripts?
                .prefix(WidgetBasicContainerView.maximumCount(family: context.family)) {
                return Entry(date: Date(), scripts: configurationScripts.compactMap({ intentScriptEntry in
                    .init(
                        script: .init(
                            id: intentScriptEntry.id,
                            name: intentScriptEntry.displayString,
                            iconName: intentScriptEntry.iconName
                        ),
                        serverId: intentScriptEntry.serverId,
                        serverName: intentScriptEntry.serverName
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
                script: .init(id: "1", name: "Run Script", iconName: nil),
                serverId: "1",
                serverName: "Home"
            )],
            showServerName: true, showConfirmationDialog: true
        )
    }

    private func showServerName() -> Bool {
        Current.servers.all.count > 1
    }

    private func suggestions() async -> [Server: [HAScript]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [HAScript]] = [:]
            var serverCheckedCount = 0
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                (
                    Current.diskCache
                        .value(
                            for: HAScript
                                .cacheKey(serverId: server.identifier.rawValue)
                        ) as? Promise<[HAScript]>
                )?.pipe(to: { result in
                    switch result {
                    case let .fulfilled(scripts):
                        let scripts = scripts.sorted(by: { $0.name ?? "" < $1.name ?? "" })
                        entities[server] = scripts
                    case let .rejected(error):
                        Current.Log
                            .error(
                                "Failed to get scripts cache for server identifier: \(server.identifier.rawValue), error: \(error.localizedDescription)"
                            )
                    }
                    serverCheckedCount += 1
                    if serverCheckedCount == Current.servers.all.count {
                        continuation.resume(returning: entities)
                    }
                })
            }
        }
    }
}
