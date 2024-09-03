import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlScriptItem {
    let intentScriptEntity: IntentScriptEntity
    let icon: SFSymbolEntity
    let showConfirmationNotification: Bool
}

@available(iOSApplicationExtension 18, *)
struct ControlScriptsValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlScriptsConfiguration) async throws -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog
        )
    }

    func placeholder(for configuration: ControlScriptsConfiguration) -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog
        )
    }

    func previewValue(configuration: ControlScriptsConfiguration) -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog
        )
    }

    private func placeholder() -> IntentScriptEntity {
        .init(
            id: UUID().uuidString,
            serverId: "",
            serverName: "",
            displayString: L10n.Widgets.Controls.Scripts.placeholderTitle,
            iconName: "applescript.fill"
        )
    }

    private func placeholderIcon() -> SFSymbolEntity {
        .init(id: "applescript.fill")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ControlScriptsConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.scripts.description", defaultValue: "Run Script")

    @Parameter(
        title: .init("app_intents.scripts.script.title", defaultValue: "Script")
    )
    var script: IntentScriptEntity?
    @Parameter(
        title: .init("app_intents.scripts.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?

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
}
