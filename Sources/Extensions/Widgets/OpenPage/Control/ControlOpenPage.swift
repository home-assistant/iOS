import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenPage: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenPage.rawValue,
            provider: ControlOpenPageValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenPageAppIntent()
                intent.page = template.page
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.page.panel.title, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.OpenPage.title))
    }
}
