import AppIntents
import Foundation
import GRDB
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlLight: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlLight.rawValue,
            provider: ControlLightsValueProvider()
        ) { template in
            ControlWidgetToggle(isOn: template.value, action: {
                let intent = LightIntent()
                intent.light = .init(
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
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Light.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Light.description))
    }
}
