import AppIntents
import Foundation
import WidgetKit

@available(iOS 17.0, *)
struct WidgetRefreshAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.refresh_title",
        defaultValue: "Refresh widget"
    )
    static var isDiscoverable: Bool = false

    // No translation needed below, this is not a discoverable intent
    @Parameter(title: "Widget kind")
    var widgetKind: String?

    func perform() async throws -> some IntentResult {
        AppIntentHaptics.notify()
        if let widgetKind {
            WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        } else {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}
