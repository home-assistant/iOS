import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlSwitch: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlSwitch.rawValue,
            provider: ControlSwitchValueProvider()
        ) { template in
            ControlWidgetToggle(isOn: template.value, action: {
                let intent = SwitchIntent()
                intent.entity = .init(
                    id: template.id,
                    entityId: template.entityId,
                    serverId: template.serverId,
                    displayString: template.name,
                    iconName: template.icon.id
                )
                intent.value = !template.value
                return intent
            }()) {
                Label(template.name, systemImage: template.icon.id)
            }
            .tint(.yellow)
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Switch.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Switch.description))
    }
}
