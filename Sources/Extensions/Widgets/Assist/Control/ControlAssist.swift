import Foundation
import AppIntents
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
                intent.target = template.pipeline
                return intent
            }()) {
                // ControlWidget can only display SF Symbol (Custom Assist SFSymbol)
                Label("Assist", image: "message-processing-outline")
            }
        }
        .displayName(.init(stringLiteral: "Assist"))
    }
}
