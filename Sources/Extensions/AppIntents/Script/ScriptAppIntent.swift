import AppIntents
import Foundation
import PromiseKit
import Shared
import SwiftUI

@available(iOS 17, *)
final class ScriptAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init("widgets.script.description.title", defaultValue: "Run Script")

    @Parameter(title: LocalizedStringResource("app_intents.scripts.script.title", defaultValue: "Run Script"))
    var script: IntentScriptEntity

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scripts.show_confirmation_dialog.title",
            defaultValue: "Confirmation notification"
        ),
        description: LocalizedStringResource(
            "app_intents.scripts.show_confirmation_dialog.description",
            defaultValue: "Shows confirmation notification after executed"
        ),
        default: true
    )
    var showConfirmationDialog: Bool

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        let success: Bool = try await withCheckedThrowingContinuation { continuation in
            guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == script.serverId }) else {
                continuation.resume(returning: false)
                return
            }
            let domain = Domain.script.rawValue
            let service = script.id.replacingOccurrences(of: "\(domain).", with: "")
            Current.api(for: server).CallService(domain: domain, service: service, serviceData: [:])
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
        if showConfirmationDialog {
            LocalNotificationDispatcher().send(.init(
                id: .debug,
                title: success ? L10n.AppIntents.Scripts.SuccessMessage.content(script.displayString) : L10n.AppIntents
                    .Scripts.FailureMessage.content(script.displayString)
            ))
        }
        return .result(value: success)
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentScriptEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Script")

    static let defaultQuery = IntentScriptAppEntityQuery()

    var id: String
    var serverId: String
    var displayString: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(id: String, serverId: String, displayString: String) {
        self.id = id
        self.serverId = serverId
        self.displayString = displayString
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentScriptAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentScriptEntity] {
        await getScriptEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = await getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentScriptEntity> {
        let scriptsPerServer = await getScriptEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentScriptEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getScriptEntities(matching string: String? = nil) async -> [Server: [IntentScriptEntity]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [IntentScriptEntity]] = [:]
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
                        var scripts = scripts.sorted(by: { $0.name ?? "" < $1.name ?? "" })
                        if let string {
                            scripts = scripts.filter { $0.name?.contains(string) ?? false }
                        }

                        entities[server] = scripts.compactMap { script in
                            IntentScriptEntity(
                                id: script.id,
                                serverId: server.identifier.rawValue,
                                displayString: script.name ?? "Unknown"
                            )
                        }
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
