import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 17, *)
struct ReloadWidgetsAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(stringLiteral: "widgets.reload_widgets.app_intent.title")
    static var description = IntentDescription(.init(stringLiteral: "widgets.reload_widgets.app_intent.description"))
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
