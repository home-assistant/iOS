import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlScene: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlScene.rawValue,
            provider: ControlScenesValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = SceneAppIntent()
                intent.scene = .init(
                    id: template.intentSceneEntity.id,
                    serverId: template.intentSceneEntity.serverId,
                    serverName: template.intentSceneEntity.serverName,
                    displayString: template.intentSceneEntity.displayString,
                    iconName: template.icon.id
                )
                intent.showConfirmationNotification = template.showConfirmationNotification
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.intentSceneEntity.displayString, systemImage: template.icon.id)
            }
        }
        .displayName(.init(stringLiteral: L10n.Widgets.Controls.Scene.displayName))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Scene.description))
    }
}
