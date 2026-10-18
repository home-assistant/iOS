import AppIntents
import Foundation
import Shared

@available(iOS 18, *)
struct CoverIntent: SetValueIntent {
    static var title: LocalizedStringResource = .init("app_intents.intent.cover.title", defaultValue: "Control cover")

    @Parameter(title: .init("app_intents.cover.title", defaultValue: "Cover"))
    var entity: IntentCoverEntity

    @Parameter(title: .init("app_intents.state.target", defaultValue: "Target state"))
    var value: Bool

    @Parameter(title: .init("app_intents.state.toggle", defaultValue: "Toggle"), default: false)
    var toggle: Bool

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == entity.serverId }),
              let connection = Current.api(for: server)?.connection else {
            return .result(dialog: .init(stringLiteral: L10n.AppIntents.Error.noServer))
        }

        var service = Service.toggle.rawValue
        if !toggle {
            service = value ? Service.openCover.rawValue : Service.closeCover.rawValue
        }

        do {
            try await connection.send(.callService(
                domain: .init(stringLiteral: Domain.cover.rawValue),
                service: .init(stringLiteral: service),
                data: [
                    "entity_id": entity.entityId,
                ]
            )).promise.async()
        } catch {
            throw ShortcutAppIntentError(error.localizedDescription)
        }

        let dialog: String
        if toggle {
            dialog = L10n.AppIntents.Dialog.toggled(entity.displayString)
        } else {
            dialog = value
                ? L10n.AppIntents.Dialog.opened(entity.displayString)
                : L10n.AppIntents.Dialog.closed(entity.displayString)
        }
        return .result(dialog: .init(stringLiteral: dialog))
    }
}
