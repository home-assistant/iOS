import Foundation

/// Everything a `HAAPIConnection` needs, injected as closures so the package stays free of any
/// app types (Server, TokenManager, ConnectionInfo live outside; an adapter bridges them here).
public struct HAAPIConfiguration: Sendable {
    /// Resolves the full websocket URL (`wss://host/api/websocket`) for the next connection
    /// attempt. Called once per attempt so URL selection (internal vs external) stays fresh.
    public var webSocketURLProvider: @Sendable () async throws -> URL
    /// Resolves a currently-valid access token. Called on every (re)connect, after
    /// `auth_required`, so token refresh can happen inside the provider.
    public var accessTokenProvider: @Sendable () async throws -> String
    /// Builds the URLSession for a connection attempt — the hook for mTLS client certificates and
    /// self-signed-certificate handling via a custom delegate. Called once per attempt; the
    /// returned session is invalidated (`finishTasksAndInvalidate`) when that attempt ends, so
    /// providers must return a fresh session each call.
    public var sessionProvider: @Sendable () -> URLSession
    /// Extra HTTP headers for the websocket handshake request (e.g. `User-Agent`).
    public var additionalHeaders: [String: String]
    /// How often a protocol-level `ping` is sent while connected.
    public var heartbeatInterval: Duration
    /// How long to wait for the matching `pong` before tearing the connection down.
    public var heartbeatTimeout: Duration
    public var reconnectPolicy: HAAPIReconnectPolicy

    public init(
        webSocketURLProvider: @escaping @Sendable () async throws -> URL,
        accessTokenProvider: @escaping @Sendable () async throws -> String,
        sessionProvider: @escaping @Sendable () -> URLSession = { URLSession(configuration: .default) },
        additionalHeaders: [String: String] = [:],
        heartbeatInterval: Duration = .seconds(30),
        heartbeatTimeout: Duration = .seconds(10),
        reconnectPolicy: HAAPIReconnectPolicy = .exponentialBackoff
    ) {
        self.webSocketURLProvider = webSocketURLProvider
        self.accessTokenProvider = accessTokenProvider
        self.sessionProvider = sessionProvider
        self.additionalHeaders = additionalHeaders
        self.heartbeatInterval = heartbeatInterval
        self.heartbeatTimeout = heartbeatTimeout
        self.reconnectPolicy = reconnectPolicy
    }
}
