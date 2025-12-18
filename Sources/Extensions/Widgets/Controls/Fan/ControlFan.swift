import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlFan: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlFan.rawValue,
            provider: ControlFanValueProvider()
        ) { template in
            ControlWidgetToggle(isOn: template.value, action: {
                let intent = FanIntent()
                intent.fan = .init(
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
            .tint(.blue)
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Fan.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Fan.description))
    }
}
