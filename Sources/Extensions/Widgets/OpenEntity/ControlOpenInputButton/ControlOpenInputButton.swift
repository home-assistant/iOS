import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenInputButton: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenInputButton.rawValue,
            provider: ControlOpenInputButtonValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenInputButtonAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenInputButton.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenInputButton.description))
    }
}
