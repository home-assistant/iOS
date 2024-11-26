import AppIntents
import ActivityKit
import AudioToolbox
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.4, *)
final class ScriptAppIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = .init("widgets.script.description.title", defaultValue: "Run Script")

    @Parameter(title: LocalizedStringResource("app_intents.scripts.script.title", defaultValue: "Run Script"))
    var script: IntentScriptEntity

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.notify_when_run.title",
            defaultValue: "Notify when run"
        ),
        description: LocalizedStringResource(
            "app_intents.notify_when_run.description",
            defaultValue: "Shows notification after executed"
        ),
        default: true
    )
    var showConfirmationNotification: Bool

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scripts.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: false
    )
    var hapticConfirmation: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        if #available(iOS 18, *) {
            let attributes = ProgressActivityAttributes(timerId: "1", date: "")

            let contentState = ProgressActivityAttributes.ContentState(percentageCompleted: 0)

            let content = ActivityContent(
                state: contentState,
                staleDate: nil,
                relevanceScore: 0
            )
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: .token
                )
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await activity.update(using: .init(percentageCompleted: 1, success: true))
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                await activity.end(nil)
            } catch {
                fatalError(error.localizedDescription)
            }
        }

        return .result(value: true)
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentScriptEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Script")

    static let defaultQuery = IntentScriptAppEntityQuery()

    var id: String
    var entityId: String
    var serverId: String
    var serverName: String
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentScriptAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentScriptEntity] {
        getScriptEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getScriptEntities(matching string: String? = nil) -> [(Server, [IntentScriptEntity])] {
        var scriptEntities: [(Server, [IntentScriptEntity])] = []
        let entities = ControlEntityProvider(domain: .script).getEntities(matching: string)

        for (server, values) in entities {
            scriptEntities.append((server, values.map({ entity in
                IntentScriptEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue
                )
            })))
        }

        return scriptEntities
    }
}
