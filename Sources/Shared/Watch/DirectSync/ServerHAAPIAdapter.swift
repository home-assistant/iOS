#if os(watchOS)
import Foundation
import HAAPI

/// Bridges the app's `Server` (URL selection, token refresh, mTLS/self-signed session) into
/// HAAPI's dependency-free configuration closures. This is the only place the watch connects
/// HAAPI to the HANetworking world.
enum ServerHAAPIAdapter {
    static func configuration(for server: Server) -> HAAPIConfiguration {
        HAAPIConfiguration(
            webSocketURLProvider: {
                guard let baseURL = await server.activeURL() else {
                    throw WatchDirectSyncError.noActiveURL
                }
                return webSocketURL(from: baseURL)
            },
            accessTokenProvider: {
                try await bearerToken(for: server)
            },
            sessionProvider: {
                // The delegate answers mTLS client-certificate challenges and applies the server's
                // security exceptions — required for local/self-signed servers. HAAPI invalidates
                // the session after each connection attempt, releasing the delegate.
                HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
            },
            additionalHeaders: ["User-Agent": HomeAssistantAPI.userAgent]
        )
    }

    /// `https://host/` → `wss://host/api/websocket` (and `http` → `ws`).
    static func webSocketURL(from baseURL: URL) -> URL {
        let socketURL = baseURL.appendingPathComponent("api/websocket")
        guard var components = URLComponents(url: socketURL, resolvingAgainstBaseURL: false) else {
            return socketURL
        }
        switch components.scheme {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: break
        }
        return components.url ?? socketURL
    }

    /// A currently-valid access token, refreshing if needed — the same bridge
    /// `ComplicationStateFetcher.bearerToken(for:)` uses for the watch's REST calls.
    private static func bearerToken(for server: Server) async throws -> String {
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        return try await withCheckedThrowingContinuation { continuation in
            tokenManager.bearerToken.done { token, _ in
                continuation.resume(returning: token)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }
}
#endif
