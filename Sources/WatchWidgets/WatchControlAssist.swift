import AppIntents
import SwiftUI
import WidgetKit

@available(watchOS 26.0, *)
struct WatchControlAssist: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: WatchWidgetConstants.controlAssistKind) {
            ControlWidgetButton(action: WatchAssistAppIntent()) {
                Label(WatchWidgetConstants.assistTitle, image: WatchWidgetConstants.assistIconAssetName)
            }
            .tint(.haPrimary)
        }
        .displayName(.init(stringLiteral: WatchWidgetConstants.assistTitle))
        .description(.init(stringLiteral: WatchWidgetConstants.assistControlDescription))
    }
}
