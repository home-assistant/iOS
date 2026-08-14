import Foundation

/// Drives Home Assistant's config flow REST API (`/api/config/config_entries/flow`), the same
/// endpoints the frontend's "Add integration" dialog uses.
///
/// It exists so the app can add an integration on the user's behalf with every field already
/// filled in — the frontend has no way to pre-populate a config flow from a URL, so handing the
/// user a half-configured dialog isn't an option. Both calls need an admin token; a non-admin
/// user gets an `unacceptableStatus` back from `HomeAssistantRESTClient`.
public enum HomeAssistantConfigFlowClient {
    private static let path = ["config", "config_entries", "flow"]

    /// Starts a flow for `handler` (an integration domain, e.g. `mjpeg`) and returns its first step.
    public static func start(server: Server, handler: String) async throws -> ConfigFlowOutcome {
        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            method: .post,
            path: path,
            body: [
                "handler": handler,
                "show_advanced_options": false,
            ]
        )
        return try ConfigFlowOutcome(json: json)
    }

    /// Submits `userInput` to the step identified by `flowID`.
    public static func submit(
        server: Server,
        flowID: String,
        userInput: [String: Any]
    ) async throws -> ConfigFlowOutcome {
        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            method: .post,
            path: path + [flowID],
            body: userInput
        )
        return try ConfigFlowOutcome(json: json)
    }

    /// Runs a single-step flow end to end: starts it, then answers its first form with `userInput`.
    ///
    /// Anything other than a form on the first step (an integration that aborts immediately, say)
    /// is returned as-is so callers can report the reason.
    public static func createEntry(
        server: Server,
        handler: String,
        userInput: [String: Any]
    ) async throws -> ConfigFlowOutcome {
        let started = try await start(server: server, handler: handler)
        guard case let .form(flowID, _) = started else { return started }
        return try await submit(server: server, flowID: flowID, userInput: userInput)
    }
}
