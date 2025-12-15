import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenButton.rawValue,
            provider: ControlOpenButtonValueProvider()
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
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenButton.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenButton.description))
    }
}
