import AppIntents
import Foundation
import Shared

/// The Focus Filter the user adds to a Focus in Settings › Focus, picking one of the names they
/// created in the app. iOS runs this when that Focus activates, which is the only moment it tells
/// us anything about _which_ Focus is running.
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
        Current.focusFilter.setActiveFocusName(focusName?.name)
        Current.Log.info("focus filter set focus name to \(focusName?.name ?? "<none>")")

        for api in Current.apis {
            do {
                try await api.UpdateSensors(trigger: .Signaled).async(timeout: 10)
            } catch {
                Current.Log.error("focus filter failed to update sensors on \(api.server.info.name): \(error)")
            }
        }

        return .result()
    }
}
