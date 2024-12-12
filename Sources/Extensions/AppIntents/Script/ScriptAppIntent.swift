import AppIntents
import AudioToolbox
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared
import SwiftUI

@available(iOS 16.4, *)
final class ScriptAppIntent: AppIntent {
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
        if hapticConfirmation {
            // Unfortunately this is the only 'haptics' that work with widgets
            // ideally in the future this should use CoreHaptics for a better experience
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }

        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == script.serverId }),
                  let api = Current.api(for: server) else {
                continuation.resume(returning: false)
                return
            }
            let domain = Domain.script.rawValue
            let service = script.entityId.replacingOccurrences(of: "\(domain).", with: "")
            api.CallService(domain: domain, service: service, serviceData: [:])
                .pipe { [weak self] result in
                    switch result {
                    case .fulfilled:
                        continuation.resume(returning: true)
                    case let .rejected(error):
                        Current.Log
                            .error(
                                "Failed to execute script from ScriptAppIntent, name: \(String(describing: self?.script.displayString)), error: \(error.localizedDescription)"
                            )
                        continuation.resume(returning: false)
                    }
                }
        }
        if showConfirmationNotification {
            LocalNotificationDispatcher().send(.init(
                id: .scriptAppIntentRun,
                title: success ? L10n.AppIntents.Scripts.SuccessMessage.content(script.displayString) : L10n.AppIntents
                    .Scripts.FailureMessage.content(script.displayString)
            ))
        }

        DataWidgetsUpdater.update()

        return .result(value: success)
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
        let entities = ControlEntityProvider(domains: [.script]).getEntities(matching: string)

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
