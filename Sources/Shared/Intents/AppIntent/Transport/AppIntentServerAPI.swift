import Foundation
import HAKit

/// The server operations App Intents need, expressed in the transport each platform can actually use.
///
/// iOS, macOS and CarPlay run them over the WebSocket connection HAKit already maintains. watchOS
/// can't: raw and stream sockets are denied by NECP policy on real watch hardware (see Starscream
/// #957 / Apple DTS thread 127232, and `MagicItem.execute`, which splits the same way), so there the
/// identical operations go over the REST API on `URLSession`. One kind of mTLS server takes the REST
/// path on every platform — see `transport(for:)`.
///
/// Intents call these entry points and stay platform-agnostic — the transport choice lives here and
/// only here, so a new intent gets watch support for free.
public enum AppIntentServerAPI {
    /// Which transport a server's App Intent requests go over.
    public enum Transport: Equatable {
        case webSocket
        case rest
    }

    /// The transport `server`'s requests go over right now.
    ///
    /// watchOS is always REST (see the type's documentation). Elsewhere the WebSocket is preferred,
    /// with one exception: a server reached over HTTPS whose client certificate (mTLS) chains
    /// through an intermediate CA. HAKit's mTLS WebSocket engine hands `URLSession` the bare
    /// `SecIdentity`, so the intermediates stored at import never reach the server, and a reverse
    /// proxy that only trusts the root CA rejects the handshake — the request then never completes.
    /// The REST session presents the full chain (`ClientCertificateManager.urlCredential(for:)`),
    /// so those servers use it instead. Plain HTTP (typically the local URL) never presents a
    /// certificate, so the WebSocket stays in use there.
    ///
    /// `hasIntermediateCertificates` is the Keychain lookup, injectable for tests.
    public static func transport(
        for server: Server,
        hasIntermediateCertificates: (ClientCertificate) -> Bool = {
            ClientCertificateManager.shared.hasIntermediateCertificates(for: $0)
        }
    ) -> Transport {
        #if os(watchOS)
        return .rest
        #else
        // Synchronous URL evaluation on purpose: intents refresh network information before they
        // run, so the last-known state is the current one (same as `HomeAssistantRESTClient`).
        guard let clientCertificate = server.info.connection.clientCertificate,
              server.activeURLUsingLastKnownNetworkState()?.scheme?.lowercased() == "https",
              hasIntermediateCertificates(clientCertificate) else {
            return .webSocket
        }
        return .rest
        #endif
    }

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
        #if !os(watchOS)
        if transport(for: server) == .webSocket {
            return try await callActionViaWebSocket(
                server: server,
                domain: domain,
                service: service,
                data: data,
                returnResponse: returnResponse
            )
        }
        #endif
        return try await callActionViaREST(
            server: server,
            domain: domain,
            service: service,
            data: data,
            returnResponse: returnResponse
        )
    }

    /// Renders a Jinja template. Only admins may do this, on either transport.
    public static func renderTemplate(server: Server, template: String) async throws -> String {
        #if !os(watchOS)
        if transport(for: server) == .webSocket {
            return try await renderTemplateViaWebSocket(server: server, template: template)
        }
        #endif
        return try await renderTemplateViaREST(server: server, template: template)
    }

    /// Every action the server exposes, sorted by `domain.service`.
    ///
    /// The WebSocket build enriches them with the frontend's service icons and translations; REST
    /// has no equivalent endpoint for either, so over REST the raw names and descriptions are used.
    public static func actionDefinitions(server: Server) async throws -> [IntentActionDefinition] {
        #if !os(watchOS)
        if transport(for: server) == .webSocket {
            return try await actionDefinitionsViaWebSocket(server: server)
        }
        #endif
        return try await actionDefinitionsViaREST(server: server)
    }

    /// The server's entities in `domain`, sorted by friendly name.
    public static func entities(server: Server, domain: Domain) async throws -> [HAEntity] {
        #if !os(watchOS)
        if transport(for: server) == .webSocket {
            return try await entitiesViaWebSocket(server: server, domain: domain)
        }
        #endif
        return try await entitiesViaREST(server: server, domain: domain)
    }

    /// Runs a written prompt through Assist and returns the spoken answer.
    ///
    /// The WebSocket build runs the selected Assist pipeline end to end. REST has no pipeline
    /// runner, so that path posts to the conversation API using the pipeline's own conversation
    /// agent and language — the same agent the pipeline would have used for its intent stage.
    public static func assist(server: Server, prompt: String, pipelineId: String?) async throws -> String {
        #if !os(watchOS)
        if transport(for: server) == .webSocket {
            return try await assistViaWebSocket(server: server, prompt: prompt, pipelineId: pipelineId)
        }
        #endif
        return try await assistViaREST(server: server, prompt: prompt, pipelineId: pipelineId)
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
