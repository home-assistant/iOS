import Foundation
import HAKit

/// The server operations App Intents need, expressed in the transport each platform can actually use.
///
/// iOS, macOS and CarPlay run them over the WebSocket connection HAKit already maintains. watchOS
/// can't: raw and stream sockets are denied by NECP policy on real watch hardware (see Starscream
/// #957 / Apple DTS thread 127232, and `MagicItem.execute`, which splits the same way), so there the
/// identical operations go over the REST API on `URLSession`.
///
/// Intents call these entry points and stay platform-agnostic — the transport choice lives here and
/// only here, so a new intent gets watch support for free.
public enum AppIntentServerAPI {
    /// Performs `domain.service`, optionally asking for the action's response.
    ///
    /// `returnResponse` must only be `true` for actions that support one, otherwise Home Assistant
    /// rejects the call.
    public static func callAction(
        server: Server,
        domain: String,
        service: String,
        data: [String: Any],
        returnResponse: Bool
    ) async throws -> CallServiceResponse {
        #if os(watchOS)
        return try await callActionViaREST(
            server: server,
            domain: domain,
            service: service,
            data: data,
            returnResponse: returnResponse
        )
        #else
        return try await callActionViaWebSocket(
            server: server,
            domain: domain,
            service: service,
            data: data,
            returnResponse: returnResponse
        )
        #endif
    }

    /// Renders a Jinja template. Only admins may do this, on either transport.
    public static func renderTemplate(server: Server, template: String) async throws -> String {
        #if os(watchOS)
        return try await renderTemplateViaREST(server: server, template: template)
        #else
        return try await renderTemplateViaWebSocket(server: server, template: template)
        #endif
    }

    /// Every action the server exposes, sorted by `domain.service`.
    ///
    /// The WebSocket build enriches them with the frontend's service icons and translations; REST
    /// has no equivalent endpoint for either, so on watchOS the raw names and descriptions are used.
    public static func actionDefinitions(server: Server) async throws -> [IntentActionDefinition] {
        #if os(watchOS)
        return try await actionDefinitionsViaREST(server: server)
        #else
        return try await actionDefinitionsViaWebSocket(server: server)
        #endif
    }

    /// The server's entities in `domain`, sorted by friendly name.
    public static func entities(server: Server, domain: Domain) async throws -> [HAEntity] {
        #if os(watchOS)
        return try await entitiesViaREST(server: server, domain: domain)
        #else
        return try await entitiesViaWebSocket(server: server, domain: domain)
        #endif
    }

    /// The live state of a single entity, with its attributes.
    public static func entityState(server: Server, entityId: String) async throws -> HAEntity {
        #if os(watchOS)
        return try await entityStateViaREST(server: server, entityId: entityId)
        #else
        return try await entityStateViaWebSocket(server: server, entityId: entityId)
        #endif
    }

    /// Runs a written prompt through Assist and returns the spoken answer.
    ///
    /// The WebSocket build runs the selected Assist pipeline end to end. REST has no pipeline
    /// runner, so the watch posts to the conversation API using the pipeline's own conversation
    /// agent and language — the same agent the pipeline would have used for its intent stage.
    public static func assist(server: Server, prompt: String, pipelineId: String?) async throws -> String {
        #if os(watchOS)
        return try await assistViaREST(server: server, prompt: prompt, pipelineId: pipelineId)
        #else
        return try await assistViaWebSocket(server: server, prompt: prompt, pipelineId: pipelineId)
        #endif
    }

    /// How long a single App Intent request may take before it fails with a timeout. Entity queries
    /// populate a picker the user is waiting on, so they can't wait indefinitely for a connection
    /// that may never come up.
    static var requestTimeout: TimeInterval { 10 }

    /// Orders entities the way a picker should read: by friendly name, falling back to the entity id.
    /// Shared by both transports so a list looks the same wherever it was fetched.
    static func sortedByDisplayName(_ entities: [HAEntity]) -> [HAEntity] {
        entities.sorted {
            ($0.attributes.friendlyName ?? $0.entityId).localizedCaseInsensitiveCompare(
                $1.attributes.friendlyName ?? $1.entityId
            ) == .orderedAscending
        }
    }
}
