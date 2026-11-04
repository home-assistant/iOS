import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct ButtonIntent: AppIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.button.title", defaultValue: "Press button")

    @Parameter(title: .init("app_intents.button.title", defaultValue: "Button"))
    var entity: IntentButtonEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result(dialog: .init(stringLiteral: L10n.AppIntents.Error.noServer))
        }

        // Button domains use the "press" service
        let domain = Domain(entityId: entity.entityId) ?? .button

        do {
            try await connection.send(.callService(
                domain: .init(stringLiteral: domain.rawValue),
                service: .init(stringLiteral: "press"),
                data: [
                    "entity_id": entity.entityId,
                ]
            )).promise.async()
        } catch {
            throw ShortcutAppIntentError(error.localizedDescription)
        }
        return .result(dialog: .init(stringLiteral: L10n.AppIntents.Dialog.pressed(entity.displayString)))
    }
}
