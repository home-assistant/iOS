import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenSwitch: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenSwitch.rawValue,
            provider: ControlOpenSwitchValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenEntityAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.displayText ?? template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenSwitch.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenSwitch.description))
    }
}
