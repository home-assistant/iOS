import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenScene: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenScene.rawValue,
            provider: ControlOpenSceneValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenSceneAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenScene.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenScene.description))
    }
}
