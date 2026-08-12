import Foundation
import GRDB
import HAKit

/// REST implementations of `AppIntentServerAPI`, used on watchOS where no WebSocket is available.
///
/// Compiled on every platform so the payload building and response parsing stay covered by the iOS
/// unit-test target; only `AppIntentServerAPI` decides which transport actually runs.
extension AppIntentServerAPI {
    static func callActionViaREST(
        server: Server,
        domain: String,
        service: String,
        data: [String: Any],
        returnResponse: Bool
    ) async throws -> CallServiceResponse {
        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            method: .post,
            path: ["services", domain, service],
            // Valueless flag, matching `POST /api/services/<domain>/<service>?return_response`.
            query: returnResponse ? [URLQueryItem(name: "return_response", value: nil)] : [],
            body: data,
            timeout: requestTimeout
        )
        return try callServiceResponse(from: json)
    }

    static func renderTemplateViaREST(server: Server, template: String) async throws -> String {
        let data = try await HomeAssistantRESTClient.send(
            server: server,
            method: .post,
            path: ["template"],
            body: ["template": template],
            timeout: requestTimeout
        )
        // `POST /api/template` answers with the rendered text itself, not JSON.
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func actionDefinitionsViaREST(server: Server) async throws -> [IntentActionDefinition] {
        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            path: ["services"],
            timeout: requestTimeout
        )
        return actionDefinitions(fromRESTServices: json)
    }

    static func entitiesViaREST(server: Server, domain: Domain) async throws -> [HAEntity] {
        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            path: ["states"],
            timeout: requestTimeout
        )
        return entities(fromRESTStates: json, domain: domain)
    }

    static func assistViaREST(server: Server, prompt: String, pipelineId: String?) async throws -> String {
        // REST has no pipeline runner, so the pipeline's own conversation agent and language are
        // used — the same ones its intent stage would have run with. "Preferred" (no id) leaves both
        // out and lets the server pick its default agent.
        let selected = try? await pipeline(id: pipelineId, serverId: server.identifier.rawValue)

        var body: [String: Any] = ["text": prompt]
        if let agentId = selected?.conversationEngine {
            body["agent_id"] = agentId
        }
        if let language = selected?.conversationLanguage ?? selected?.language {
            body["language"] = language
        }

        let json = try await HomeAssistantRESTClient.sendForJSON(
            server: server,
            method: .post,
            path: ["conversation", "process"],
            body: body,
            timeout: requestTimeout
        )
        return try assistAnswer(from: json)
    }

    /// The stored pipeline for `id`, or nil when "Preferred" is selected or it isn't known locally.
    private static func pipeline(id: String?, serverId: String) async throws -> Pipeline? {
        guard let id, id.isEmpty == false else { return nil }
        let stored = try await Current.database().read { db in
            try AssistPipelines.fetchAll(db)
        }
        return stored
            .first { $0.serverId == serverId }?
            .pipelines
            .first { $0.id == id }
    }

    // MARK: - Response parsing (exposed for tests)

    /// Maps a `POST /api/services/…` body onto the same `CallServiceResponse` the WebSocket returns.
    ///
    /// With `?return_response` Home Assistant answers `{"changed_states": […], "service_response": …}`;
    /// without it, a bare array of changed states, which carries no response.
    public static func callServiceResponse(from json: Any) throws -> CallServiceResponse {
        var payload: [String: Any] = [:]
        if let dictionary = json as? [String: Any], let serviceResponse = dictionary["service_response"] {
            payload["response"] = serviceResponse
        }
        return try CallServiceResponse(data: HAData(value: payload))
    }

    /// Maps a `GET /api/services` body, which lists services per domain and carries neither the
    /// frontend's icons nor its translations.
    public static func actionDefinitions(fromRESTServices json: Any) -> [IntentActionDefinition] {
        guard let domains = json as? [[String: Any]] else { return [] }

        return domains.flatMap { entry -> [IntentActionDefinition] in
            guard let domain = entry["domain"] as? String,
                  let services = entry["services"] as? [String: [String: Any]] else {
                return []
            }
            return services.map { service, metadata in
                IntentActionDefinition(
                    domain: domain,
                    service: service,
                    name: metadata["name"] as? String,
                    actionDescription: metadata["description"] as? String,
                    descriptionPlaceholders: [:],
                    translationKey: metadata["translation_key"] as? String,
                    icon: metadata["icon"] as? String,
                    supportsResponse: metadata["response"] is [String: Any],
                    translations: [:]
                )
            }
        }
        .sorted { first, second in
            first.actionId.localizedCaseInsensitiveCompare(second.actionId) == .orderedAscending
        }
    }

    /// Maps a `GET /api/states` body, keeping only `domain` and decoding with the same HAKit model
    /// the WebSocket pipeline uses.
    public static func entities(fromRESTStates json: Any, domain: Domain) -> [HAEntity] {
        guard let states = json as? [[String: Any]] else { return [] }

        let prefix = "\(domain.rawValue)."
        let entities = states.compactMap { state -> HAEntity? in
            guard let entityId = state["entity_id"] as? String, entityId.hasPrefix(prefix) else {
                return nil
            }
            return try? HAEntity(data: HAData(value: state))
        }
        return sortedByDisplayName(entities)
    }

    /// Extracts the spoken answer from a `POST /api/conversation/process` body, throwing when the
    /// conversation agent itself reported an error.
    public static func assistAnswer(from json: Any) throws -> String {
        guard let dictionary = json as? [String: Any],
              let response = dictionary["response"] as? [String: Any] else {
            throw HomeAssistantRESTError.invalidResponse
        }

        let speech = (response["speech"] as? [String: Any])
            .flatMap { $0["plain"] as? [String: Any] }
            .flatMap { $0["speech"] as? String }

        if response["response_type"] as? String == "error" {
            throw ShortcutAppIntentError(speech ?? L10n.AppIntents.Error.invalidResponse)
        }

        guard let speech else {
            throw HomeAssistantRESTError.invalidResponse
        }
        return speech
    }
}
