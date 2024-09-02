import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlSceneItem {
    let intentSceneEntity: IntentSceneEntity
    let icon: SFSymbolEntity
}

@available(iOSApplicationExtension 18, *)
struct ControlScenesValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlSceneConfiguration) async throws -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    func placeholder(for configuration: ControlSceneConfiguration) -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    func previewValue(configuration: ControlSceneConfiguration) -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon()
        )
    }

    private func placeholder() -> IntentSceneEntity {
        .init(
            id: UUID().uuidString,
            serverId: "",
            serverName: "",
            displayString: L10n.Widgets.Controls.Scenes.placeholderTitle,
            iconName: ""
        )
    }

    private func placeholderIcon() -> SFSymbolEntity {
        .init(id: "moon.stars")
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ControlSceneConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.scripts.description", defaultValue: "Run Scene")

    @Parameter(
        title: "Scene"
    )
    var scene: IntentSceneEntity?
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
