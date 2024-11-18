import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlCover: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlCover.rawValue,
            provider: ControlCoverValueProvider()
        ) { template in
            ControlWidgetToggle(isOn: template.value, action: {
                let intent = CoverIntent()
                intent.entity = .init(
                    id: template.id,
                    entityId: template.entityId,
                    serverId: template.serverId,
                    displayString: template.name,
                    iconName: template.icon.id
                )
                intent.value = !template.value
                intent.toggle = false
                return intent
            }()) {
                Label(template.name, systemImage: template.icon.id)
            }
            .tint(Color.asset(Asset.Colors.haPrimary))
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Cover.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Cover.description))
    }
}
