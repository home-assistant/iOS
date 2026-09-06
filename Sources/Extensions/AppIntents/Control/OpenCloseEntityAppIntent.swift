import AppIntents
import Foundation
import Shared

/// Opens or closes a cover.
///
/// Separate from turn on and turn off so the wording matches the service: Home Assistant calls
/// `cover.open_cover`, and "turn on the curtain" is not how anyone asks for that.
@available(macOS 13.0, watchOS 9.4, *)
struct OpenCloseEntityAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.open_close.title",
        defaultValue: "Open or close"
    )

    static let description = IntentDescription(.init(
        "app_intents.open_close.description",
        defaultValue: "Opens or closes a Home Assistant cover"
    ))

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$action) \(\.$entity)")
    }

    @Parameter(title: .init("app_intents.open_close.action.name", defaultValue: "Action"), default: .open)
    var action: OpenCloseActionAppEnum

    @Parameter(title: .init("app_intents.open_close.entity.name", defaultValue: "Cover"))
    var entity: OpenableEntityAppEntity

    init() {}

    /// Used by the App Shortcuts, which need the verb fixed: a phrase may interpolate only one
    /// parameter, so the entity is the one it names and the action comes preset.
    init(action: OpenCloseActionAppEnum) {
        self.action = action
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await Current.connectivity.refreshNetworkInformation()
        guard let server = Current.servers.server(for: .init(rawValue: entity.serverId)) else {
            throw ShortcutAppIntentError(L10n.AppIntents.Error.noServer)
        }
        guard let domain = entity.domain, let services = domain.toggleServices else {
            throw ShortcutAppIntentError(L10n.AppIntents.Control.Error.unsupported(entity.displayString))
        }
        let service = action == .open ? services.on : services.off

        try await AppIntentServerAPI.callAction(
            server: server,
            domain: domain.serviceDomain,
            service: service.rawValue,
            data: ["entity_id": entity.entityId],
            returnResponse: false
        )
        return .result(dialog: .init(
            stringLiteral: action == .open
                ? L10n.AppIntents.OpenClose.Dialog.opened(entity.displayString)
                : L10n.AppIntents.OpenClose.Dialog.closed(entity.displayString)
        ))
    }
}
