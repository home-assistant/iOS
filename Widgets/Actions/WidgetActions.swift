import WidgetKit
import SwiftUI
import Shared
import Intents

struct WidgetActions: Widget {
    static let kind = "Actions"

    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: Self.kind,
            intent: WidgetActionsIntent.self,
            provider: WidgetActionsProvider(),
            content: { WidgetActionsContainerView(entry: $0) }
        )
        .configurationDisplayName("Actions")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
