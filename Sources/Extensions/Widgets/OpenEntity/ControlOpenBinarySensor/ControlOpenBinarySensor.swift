import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenBinarySensor: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenBinarySensor.rawValue,
            provider: ControlOpenBinarySensorValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenEntityAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenBinarySensor.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenBinarySensor.description))
    }
}
