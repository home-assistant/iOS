import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlButton.rawValue,
            provider: ControlButtonValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = ButtonIntent()
                intent.entity = .init(
                    id: template.id,
                    entityId: template.entityId,
                    serverId: template.serverId,
                    displayString: template.name,
                    iconName: template.icon.id
                )
                return intent
            }()) {
                Label(template.name, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Button.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Button.description))
    }
}
