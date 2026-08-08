import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17.0, *)
struct WidgetEnergyRefreshAppIntent: AppIntent {
    static var title: LocalizedStringResource = "widgets.energy.refresh_title"
    static var isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        AppIntentHaptics.notify()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetsKind.energy.rawValue)
        return .result()
    }
}
