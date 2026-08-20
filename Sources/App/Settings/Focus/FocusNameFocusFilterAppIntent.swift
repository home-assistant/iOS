import AppIntents
import Foundation
import Shared

/// The Focus Filter the user adds to a Focus in Settings › Focus, picking one of the names they
/// created in the app. iOS runs this when that Focus activates, which is the only moment it tells
/// us anything about _which_ Focus is running — when it runs it at all: a Focus that turns on by
/// schedule can skip it entirely, which is what `ReportFocusNameAppIntent` is for.
struct FocusNameFocusFilterAppIntent: SetFocusFilterIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.focus_filter.title",
        defaultValue: "Report Focus name"
    )

    static let description = IntentDescription(.init(
        "app_intents.focus_filter.description",
        defaultValue: "Reports the name you picked to Home Assistant while this Focus is on."
    ))

    @Parameter(title: .init("app_intents.focus_filter.focus_name.title", defaultValue: "Focus name"))
    var focusName: FocusNameAppEntity?

    var displayRepresentation: DisplayRepresentation {
        guard let focusName else {
            return .init(title: .init(
                "app_intents.focus_filter.display.none",
                defaultValue: "No Focus name picked"
            ))
        }
        return .init(title: .init(stringLiteral: focusName.name))
    }

    func perform() async throws -> some IntentResult {
        await FocusNameReporter.report(name: focusName?.name, source: .focusFilter)
        return .result()
    }
}
