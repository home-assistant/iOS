import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenPerson: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenPerson.rawValue,
            provider: ControlOpenPersonValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenPersonAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenPerson.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenPerson.description))
    }
}
