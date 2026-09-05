import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 16, *)
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
    // `openAppWhenRun` is deprecated from iOS 26; both stay until the deployment target passes 26.
    @available(iOS 26.0, watchOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
