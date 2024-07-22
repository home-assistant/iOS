import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17, *)
struct ReloadWidgetsAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "widgets.reload_widgets.app_intent.title",
        defaultValue: "Reload widgets"
    )
    static var description = IntentDescription(.init(
        "widgets.reload_widgets.app_intent.description",
        defaultValue: "Reload all widgets timelines"
    ))
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
