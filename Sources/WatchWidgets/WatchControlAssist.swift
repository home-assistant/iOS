import AppIntents
import SwiftUI
import WidgetKit

@available(watchOS 26.0, *)
struct WatchControlAssist: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WatchWidgetConstants.controlAssistKind) {
            ControlWidgetButton(action: WatchAssistAppIntent()) {
                // A control label can only draw a symbol, so this is a custom SF Symbol rather than an
                // image. It must ship in the watch app's asset catalog too — see
                // `WatchWidgetConstants.assistIconAssetName`.
                Label(WatchWidgetStrings.assistTitle, image: WatchWidgetConstants.assistIconAssetName)
            }
            .tint(.haPrimary)
        }
        .displayName(.init(stringLiteral: WatchWidgetStrings.assistTitle))
        .description(.init(stringLiteral: WatchWidgetStrings.assistControlDescription))
    }
}
