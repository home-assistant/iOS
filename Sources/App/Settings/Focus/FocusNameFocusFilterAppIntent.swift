import AppIntents
import Foundation
import PromiseKit
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

    /// It is configured in Settings › Focus and only iOS ever runs it, so it has no place in the
    /// Shortcuts editor or Spotlight.
    static let isDiscoverable = false

    /// How long to wait for the report to reach a server. iOS runs this in an app it may have just
    /// launched in the background, where a first connection is slower than in a running app.
    private static let reportTimeout: TimeInterval = 20

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

        // `Current.apis` picks each server's URL from the cached network information, which a
        // process iOS has just launched to run this doesn't have yet — leaving a server that is
        // only reachable on the home network looking unusable, and the report going nowhere.
        await Current.connectivity.refreshNetworkInformation()

        let apis = Current.apis
        guard !apis.isEmpty else {
            Current.Log.error("focus filter has no server to report the focus name to")
            return .result()
        }

        for api in apis {
            do {
                // Held in a background task: the app is likely running only because iOS woke it
                // for this, and gets suspended as soon as we return.
                try await Current.backgroundTask(withName: BackgroundTask.focusFilterSensorUpdate.rawValue) { _ in
                    api.updateFocusSensors()
                }.async(timeout: Self.reportTimeout)
            } catch {
                Current.Log.error("focus filter failed to update sensors on \(api.server.info.name): \(error)")
            }
        }

        return .result()
    }
}
