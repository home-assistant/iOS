import Foundation

/// Decides what the iPhone answers when the watch hands it a request to perform.
///
/// Split out of `WatchCommunicatorService` so the decisions — which server, whether the URL may be
/// dialled at all, which base to dial it on, and whether the answer fits back down the link — can be
/// exercised without a WatchConnectivity session or a real server. The service keeps only the
/// message plumbing.
///
/// The watch resolves its own URL, but it does so blind: routing through the phone hides the network
/// from it, so it can never satisfy the internal-URL check and falls back to a remote URL that, from
/// inside the LAN, may not resolve at all. Re-basing onto the phone's current active URL is the point
/// of the exercise — everything else is carried across untouched, down to the watch's own bearer
/// token, so this stays a transport and not a second implementation of what the watch asked for.
public enum WatchRelayRequestHandler {
    /// How the request reaches the network; the shared performer unless a test substitutes a fake.
    public typealias PerformRequest = (URLRequest, Server, URLSessionConfiguration) async throws
        -> (Data, HTTPURLResponse)
    /// The phone's current URL for a server, which is what the watch's URL gets re-based onto.
    public typealias ResolveActiveURL = (Server) async -> URL?

    /// The answer to send back for one `httpRequest` message body.
    public static func response(
        to content: [String: Any],
        servers: [Server],
        resolveActiveURL: ResolveActiveURL = { await $0.activeURL() },
        perform: PerformRequest = { request, server, configuration in
            try await ServerRequestPerformer.perform(request, server: server, configuration: configuration)
        }
    ) async -> WatchHTTPResponsePayload {
        guard let payload = WatchHTTPRequestPayload(content: content) else {
            Current.Log.error("Watch relayed an HTTP request that could not be decoded")
            return .failure(.malformedRequest, reason: "The iPhone could not decode the request")
        }

        guard let server = servers.first(where: { $0.identifier.rawValue == payload.serverId }) else {
            Current.Log.error("Watch relayed an HTTP request for unknown server \(payload.serverId)")
            return .failure(.unknownServer, reason: "The iPhone has no server \(payload.serverId)")
        }

        // The request is forwarded with the watch's own headers, bearer token included, so the phone
        // only dials hosts this server is actually configured for. A message naming a known server
        // but carrying some other URL is refused rather than forwarded.
        guard WatchRelayURLRebase.isPermitted(payload.url, connection: server.info.connection) else {
            Current.Log.error(
                "Watch relayed an HTTP request to \(payload.url.absoluteString), which is not a configured URL " +
                    "for server \(payload.serverId)"
            )
            return .failure(.malformedRequest, reason: "The URL is not configured for this server")
        }

        let url = await resolvedURL(for: payload, server: server, resolveActiveURL: resolveActiveURL)

        do {
            let (data, response) = try await perform(
                request(from: payload, url: url),
                server,
                configuration(timeout: payload.timeout)
            )
            Current.Log.info("Relayed \(payload.method) \(url.absoluteString) for the watch: \(response.statusCode)")
            return envelope(for: response, body: data)
        } catch {
            Current.Log.error("Relayed \(payload.method) \(url.absoluteString) for the watch failed: \(error)")
            return .failure(.transport, reason: error.localizedDescription)
        }
    }

    /// The URL to actually dial: the phone's current active URL for this server when the watch's URL
    /// was built on one of its configured bases, otherwise the watch's URL untouched (a cloudhook,
    /// say, which works from any network and has no base to transplant).
    static func resolvedURL(
        for payload: WatchHTTPRequestPayload,
        server: Server,
        resolveActiveURL: ResolveActiveURL
    ) async -> URL {
        guard let activeURL = await resolveActiveURL(server),
              let rebased = WatchRelayURLRebase.rebased(
                  payload.url,
                  connection: server.info.connection,
                  activeURL: activeURL
              ) else {
            return payload.url
        }
        Current.Log.info("Re-based the watch's \(payload.url.absoluteString) onto the iPhone's active URL")
        return rebased
    }

    /// The watch's request, rebuilt against whichever URL the phone settled on. Headers cross
    /// untouched: the watch owns its credentials, and this is a transport.
    static func request(from payload: WatchHTTPRequestPayload, url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = payload.method
        request.timeoutInterval = payload.timeout
        request.httpBody = payload.body
        for (field, value) in payload.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }

    /// Bounded by the budget the watch handed over, so the phone can't hold the watch past its own
    /// deadline.
    static func configuration(timeout: TimeInterval) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        return configuration
    }

    /// The server's answer, or `tooLarge` when it won't fit back down the link.
    ///
    /// An oversized response is not a failed request — the request succeeded, and only the answer is
    /// undeliverable, which is why the watch may only repeat a safe method after one.
    static func envelope(for response: HTTPURLResponse, body: Data) -> WatchHTTPResponsePayload {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, entry in
            if let field = entry.key as? String, let value = entry.value as? String {
                result[field] = value
            }
        }
        let envelope = WatchHTTPResponsePayload.response(
            statusCode: response.statusCode,
            headers: headers,
            body: body
        )

        let ceiling = WatchMessageSizeLimits.interactiveMessage - WatchMessageSizeLimits.envelopeOverhead
        guard let size = WatchConnectivityManager.estimatePayloadSize(of: envelope.content), size <= ceiling else {
            Current.Log.info("Relayed response for the watch is too large to send back; it will retry itself")
            return .failure(.tooLarge, reason: "Response exceeds the message size limit")
        }
        return envelope
    }
}
