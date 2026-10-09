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
        ) { control in
            let template = control.entity

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
            }(), label: {
                // swiftlint:disable:next sf_safe_symbol
                Label(template.name, systemImage: template.icon.id)
            }, valueLabel: { isOn in
                let title: String = control.showNextAction
                    ? (isOn ? L10n.closeLabel : L10n.openLabel)
                    : (
                        isOn
                            ? CoreStrings.componentCoverEntityComponentStateOpen
                            : CoreStrings.componentCoverEntityComponentStateClosed
                    )

                // swiftlint:disable:next sf_safe_symbol
                Label(title, systemImage: template.icon.id)
            })
            .tint(Color.haPrimary)
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Cover.title))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Cover.description))
    }
}
