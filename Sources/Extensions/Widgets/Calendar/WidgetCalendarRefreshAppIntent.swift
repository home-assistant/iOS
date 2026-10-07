import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17.0, *)
struct WidgetCalendarRefreshAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.calendar.refresh_title",
        defaultValue: "Refresh Calendar"
    )
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        AppIntentHaptics.notify()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.calendar.rawValue)
        return .result()
    }
}
