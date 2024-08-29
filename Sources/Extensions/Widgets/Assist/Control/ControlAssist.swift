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
                let intent = ControlAssistAppIntent()
//                intent.server = template.server
//                intent.pipeline = template.pipeline
//                intent.withVoice = true
                return intent
            }()) {
                // ControlWidget can only display SF Symbol (Custom Assist SFSymbol)
                Label("Assist", image: "message-processing-outline")
            }
        }
    }
}

@available(iOS 18, *)
struct ControlAssistAppIntent: AppIntent {
    static let title: LocalizedStringResource = "Assist in App"

    @Parameter(title: "Server")
    var server: IntentServerAppEntity

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
    }
}
