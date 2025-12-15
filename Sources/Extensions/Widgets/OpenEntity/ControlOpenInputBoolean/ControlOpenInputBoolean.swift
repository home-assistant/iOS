import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenInputBoolean: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenInputBoolean.rawValue,
            provider: ControlOpenInputBooleanValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenInputBooleanAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenInputBoolean.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenInputBoolean.description))
    }
}
