import AppIntents
import Foundation
import PromiseKit
import Shared

/// The Focus Filter the user adds to a Focus in Settings › Focus, picking one of the names they
/// created in the app. iOS performs it with that name when the Focus turns on, and with none when
/// it ends. That, and asking iOS for its current values, are the only ways iOS tells an app
/// _which_ Focus is on.
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

    /// Lets the Focus sensors, which live in Shared and can't see this type, ask iOS which name the
    /// filter has right now. Called once at launch.
    static func registerCurrentValuesReader() {
        Current.focusFilter.setCurrentValuesReader {
            try await currentFocusName()
        }
    }

    /// The name of the Focus that is on, or `nil` when no Focus with a name picked in this filter
    /// is on. Apple documents `notFound` only as a failure to find the current Focus
    /// configuration, which is read here as there being no Focus with this filter on. Any other
    /// error leaves the name to the filter's runs.
    static func currentFocusName(
        reading current: () async throws -> FocusNameFocusFilterAppIntent = { try await Self.current }
    ) async throws -> String? {
        do {
            return try await current().focusName?.name
        } catch SetFocusFilterIntentError.notFound {
            return nil
        }
    }

    func perform() async throws -> some IntentResult {
        // Logged before anything acts on it, and with the entity's id: this line is the only
        // record that iOS ran the filter at all, and a run carrying no name is indistinguishable
        // from a Focus ending — so a log written only after the happy path leaves "iOS never ran
        // it" and "iOS ran it with nothing" looking exactly alike in an exported log.
        Current.Log.info(
            "focus filter running with name(\(focusName?.name ?? "<none>")) " +
                "id(\(focusName?.id ?? "<none>"))"
        )
        Current.focusFilter.setActiveFocusName(focusName?.name)

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

/// `LiveActivityIntent` is not about Live Activities here: a plain `SetFocusFilterIntent` is only
/// reliably performed while the app is in the foreground, and silently skipped when iOS would have
/// to launch the app to run it — which is every Focus that starts with the app closed, so the
/// filter misses exactly the moments it exists for. The conformance opts the intent into being run
/// in the app's process in the background, which is what makes it run at all.
///
/// Declared here rather than on the type so the filter itself stays available on the iOS versions
/// below the one that introduced the protocol.
@available(iOS 17.0, *)
extension FocusNameFocusFilterAppIntent: LiveActivityIntent {}
