import AppIntents
import Foundation
import Shared

/// Locks a lock. Unlocking is deliberately absent: a misheard phrase should never open a door.
@available(macOS 13.0, watchOS 9.4, *)
struct LockEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init("app_intents.lock.title", defaultValue: "Lock")

    static let description = IntentDescription(.init(
        "app_intents.lock.description",
        defaultValue: "Locks a lock. Unlocking is not available by voice."
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("Lock \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.lock.parameter.entity", defaultValue: "Lock"))
    var entity: LockAppEntity

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: entity.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }

        try await AppIntentServerAPI.callAction(
            server: server,
            domain: Domain.lock.rawValue,
            service: Service.lock.rawValue,
            data: ["entity_id": entity.entityId],
            returnResponse: false
        )
        return .result(dialog: .init(stringLiteral: L10n.AppIntents.Dialog.locked(entity.displayString)))
    }
}
