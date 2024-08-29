import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlScriptItem {
    let intentScriptEntity: IntentScriptEntity
    let icon: SFSymbolEntity
}

@available(iOSApplicationExtension 18, *)
struct ControlScriptsValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlScriptsConfiguration) async throws -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    func placeholder(for configuration: ControlScriptsConfiguration) -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    func previewValue(configuration: ControlScriptsConfiguration) -> ControlScriptItem {
        .init(
            intentScriptEntity: configuration.script ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    private func placeholder() -> IntentScriptEntity {
        .init(
            id: UUID().uuidString,
            serverId: "",
            serverName: "",
            displayString: L10n.Widgets.Controls.Scripts.placeholderTitle,
            iconName: ""
        )
    }

    private func placeholderIcon() -> SFSymbolEntity {
        .init(id: "applescript.fill")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ControlScriptsConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.scripts.description", defaultValue: "Run Scripts")

    @Parameter(
        title: "Script"
    )
    var script: IntentScriptEntity?
    @Parameter(
        title: "Icon"
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
