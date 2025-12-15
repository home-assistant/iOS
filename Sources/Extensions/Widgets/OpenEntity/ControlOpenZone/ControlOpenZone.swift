import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenZone: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenZone.rawValue,
            provider: ControlOpenZoneValueProvider()
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
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenZone.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenZone.description))
    }
}
