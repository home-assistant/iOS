import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOSApplicationExtension 18, *)
struct ControlAutomationItem {
    let intentAutomationEntity: IntentAutomationEntity
    let icon: SFSymbolEntity
    let showConfirmationNotification: Bool
    let displayText: String?
}

@available(iOSApplicationExtension 18, *)
struct ControlAutomationsValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlAutomationConfiguration) async throws -> ControlAutomationItem {
        .init(
            intentAutomationEntity: configuration.automation ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    func placeholder(for configuration: ControlAutomationConfiguration) -> ControlAutomationItem {
        .init(
            intentAutomationEntity: configuration.automation ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    func previewValue(configuration: ControlAutomationConfiguration) -> ControlAutomationItem {
        .init(
            intentAutomationEntity: configuration.automation ?? placeholder(),
            icon: configuration.icon ?? placeholderIcon(),
            showConfirmationNotification: configuration.showConfirmationDialog,
            displayText: configuration.displayText
        )
    }

    private func placeholder() -> IntentAutomationEntity {
        .init(
            id: UUID().uuidString,
            entityId: "",
            serverId: "",
            serverName: "",
            displayString: L10n.Widgets.Controls.Automations.pendingConfiguration,
            iconName: SFSymbol.flowchart.rawValue
        )
    }

    private func placeholderIcon() -> SFSymbolEntity {
        .init(id: SFSymbol.flowchart.rawValue)
    }
}

@available(iOSApplicationExtension 18.0, *)
struct ControlAutomationConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = .init("widgets.automations.description", defaultValue: "Run Automation")

    @Parameter(
        title: .init("app_intents.automations.automation.title", defaultValue: "Automation")
    )
    var automation: IntentAutomationEntity?
    @Parameter(
        title: .init("app_intents.automations.icon.title", defaultValue: "Icon")
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
