import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenScript: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenScript.rawValue,
            provider: ControlOpenScriptValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenScriptAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenScript.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenScript.description))
    }
}
