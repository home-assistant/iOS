import AppIntents
import Foundation
import Shared

/// Reports a Focus name without waiting for iOS to run the Focus Filter, for the Focus changes it
/// never runs the filter for.
///
/// A Focus that iOS turns on by itself — a schedule, an automation, Sleep at bedtime — can replace
/// the running Focus without running any filter and without the shared Focus status changing, so
/// nothing reaches the app and the previous name keeps being reported. A Shortcuts personal
/// automation on "When <Focus> is turned on" does fire for those, and running this from it reports
/// the right name; running it with no name picked, when a Focus turns off, clears it again.
struct ReportFocusNameAppIntent: AppIntent {
    static let title: LocalizedStringResource = .init(
        "app_intents.report_focus_name.title",
        defaultValue: "Report Focus name to Home Assistant"
    )

    static let description = IntentDescription(.init(
        "app_intents.report_focus_name.description",
        defaultValue: "Reports which Focus is running, for Focus automations iOS doesn't run the Focus Filter for."
    ))

    static let openAppWhenRun = false

    @Parameter(title: .init("app_intents.report_focus_name.focus_name.title", defaultValue: "Focus name"))
    var focusName: FocusNameAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Report \(\.$focusName) to Home Assistant")
    }

    func perform() async throws -> some IntentResult {
        await FocusNameReporter.report(name: focusName?.name, source: .manual)
        return .result()
    }
}
