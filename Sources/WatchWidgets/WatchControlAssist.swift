import AppIntents
import SwiftUI
import WidgetKit

@available(watchOS 26.0, *)
struct WatchControlAssist: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WatchWidgetConstants.controlAssistKind) {
            ControlWidgetButton(action: WatchAssistAppIntent()) {
                Label(WatchWidgetStrings.assistTitle, image: WatchWidgetConstants.assistIconAssetName)
            }
            .tint(.haPrimary)
        }
        .displayName(.init(stringLiteral: WatchWidgetStrings.assistTitle))
        .description(.init(stringLiteral: WatchWidgetStrings.assistControlDescription))
    }
}
