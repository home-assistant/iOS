import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlAutomation: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlAutomation.rawValue,
            provider: ControlAutomationsValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = AutomationAppIntent()
                intent.automation = .init(
                    id: template.intentAutomationEntity.id,
                    entityId: template.intentAutomationEntity.entityId,
                    serverId: template.intentAutomationEntity.serverId,
                    serverName: template.intentAutomationEntity.serverName,
                    displayString: template.intentAutomationEntity.displayString,
                    iconName: template.icon.id
                )
                intent.showConfirmationNotification = template.showConfirmationNotification
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(
                    template.displayText ?? template.intentAutomationEntity.displayString,
                    systemImage: template.icon.id
                )
            }
            .tint(.haPrimary)
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Automation.displayName))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Automation.description))
    }
}
