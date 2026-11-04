import AppIntents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 18, *)
struct ControlOpenHomeAssistant: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WidgetsKind.controlOpenHomeAssistant.rawValue) {
            ControlWidgetButton(action: OpenHomeAssistantAppIntent()) {
                // ControlWidget can only display SF Symbol (Custom Home Assistant SFSymbol)
                Label(L10n.AppIntents.OpenHomeAssistant.title, image: "home-assistant")
            }
            .tint(.haPrimary)
        }
        .displayName(.init(stringLiteral: L10n.AppIntents.OpenHomeAssistant.title))
        .description(.init(stringLiteral: L10n.AppIntents.OpenHomeAssistant.description))
    }
}
