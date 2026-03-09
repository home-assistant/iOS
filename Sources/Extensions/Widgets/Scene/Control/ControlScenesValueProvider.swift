import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlSceneItem {
    let intentSceneEntity: IntentSceneEntity
    let icon: SFSymbolEntity
    let showConfirmationNotification: Bool
    let displayText: String?
}

@available(iOSApplicationExtension 18, *)
struct ControlScenesValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlSceneConfiguration) async throws -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    func placeholder(for configuration: ControlSceneConfiguration) -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    func previewValue(configuration: ControlSceneConfiguration) -> ControlSceneItem {
        .init(
            intentSceneEntity: configuration.scene ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    private func placeholder() -> IntentSceneEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            serverName: "",
            displayString: L10n.Widgets.Controls.Scenes.pendingConfiguration,
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
        title: .init("app_intents.scenes.scene.title", defaultValue: "Scene")
    )
    var scene: IntentSceneEntity?
    @Parameter(
        title: .init("app_intents.scenes.icon.title", defaultValue: "Icon")
    )
    var icon: SFSymbolEntity?

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
    var showConfirmationDialog: Bool
    @Parameter(
        title: .init("app_intents.display_text.title", defaultValue: "Display Text")
    )
    var displayText: String?
}
