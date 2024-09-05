import AppIntents
import Foundation
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlAssist: ControlWidget {
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: WidgetsKind.controlAssist.rawValue,
            provider: ControlAssistValueProvider()
        ) { template in
            ControlWidgetButton(action: {
                let intent = AssistAppIntent()
                intent.pipeline = template.pipeline
                return intent
            }()) {
                // ControlWidget can only display SF Symbol (Custom Assist SFSymbol)
                Label("Assist", image: Asset.SharedAssets.messageProcessingOutline.name)
            }
        }
        .displayName(.init(stringLiteral: "Assist"))
        .description(.init(stringLiteral: L10n.Widgets.Controls.Assist.description))
    }
}
