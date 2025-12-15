import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenLock: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlOpenLock.rawValue,
            provider: ControlOpenLockValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = OpenLockAppIntent()
                intent.entity = template.entity
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.entity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.OpenLock.Configuration.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.OpenLock.description))
    }
}
