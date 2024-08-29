import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlScript: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlScripts.rawValue,
            provider: ControlScriptsValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = ScriptAppIntent()
                intent.script = .init(
                    id: template.intentScriptEntity.id,
                    serverId: template.intentScriptEntity.serverId,
                    serverName: template.intentScriptEntity.serverName,
                    displayString: template.intentScriptEntity.displayString,
                    iconName: template.icon.id
                )
                return intent
            }()) {
                // ControlWidget can only display SF Symbol
                Label(template.intentScriptEntity.displayString, systemImage: template.icon.id)
            }
        }
    }
}
