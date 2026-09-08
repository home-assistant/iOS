import Foundation

/// Fetches album art from a credential-free absolute HTTPS source.
///
/// The host app cannot prepare artwork while it is not running, so the extension may fetch a
/// credential-free source when the system asks for a cold track. The extension has no Companion
/// credentials and never adds any to these requests.
public enum RemoteMediaArtworkFetcher {
    /// Enough for a comfortably large album cover. A source claiming more than this is refused
    /// before it is read, so a hostile or broken origin cannot spend the extension's ledger.
    public static let maximumBytes = 2 * 1024 * 1024
    /// Well inside the watchdog. Artwork is optional; being late is worse than being absent.
    public static let timeout: TimeInterval = 3

    /// No cookies, no credential store, no cache: nothing this process holds can be attached to a
    /// request whose destination it did not choose.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.allowsCellularAccess = true
        return URLSession(configuration: configuration)
    }()

    /// Whether this is a source the extension may fetch on its own.
    ///
    /// HTTPS only, and no user info: a URL that carries credentials in its authority is not a
    /// public reference, whatever else it looks like.
    public static func isFetchable(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https" else { return false }
        guard url.user == nil, url.password == nil else { return false }
        guard let host = url.host, !host.isEmpty else { return false }
        return true
    }

    /// The bytes and bounded diagnostic result of one artwork request.
    public struct Outcome: Sendable {
        public let data: Data?
        public let status: Int?
        public let mimeType: String?
        public let byteCount: Int
        public let reason: String
    }

    /// The image bytes, or an outcome saying why there are none.
    ///
    /// Never throws: artwork is optional and no failure of it may fail a session.
    public static func fetch(from url: URL) async -> Outcome {
        guard isFetchable(url) else {
            return .init(data: nil, status: nil, mimeType: nil, byteCount: 0, reason: "refused source")
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        // Belt and braces: `ephemeral` already holds nothing, and this says so at the request too.
        request.httpShouldHandleCookies = false

        guard let (data, response) = try? await session.data(for: request) else {
            return .init(data: nil, status: nil, mimeType: nil, byteCount: 0, reason: "unreachable")
        }
        let http = response as? HTTPURLResponse
        let mime = http?.mimeType
        guard let http, http.statusCode == 200 else {
            return .init(
                data: nil, status: http?.statusCode, mimeType: mime, byteCount: data.count,
                reason: "status"
            )
        }
        guard !data.isEmpty else {
            return .init(data: nil, status: 200, mimeType: mime, byteCount: 0, reason: "empty")
        }
        guard data.count <= maximumBytes else {
            return .init(
                data: nil, status: 200, mimeType: mime, byteCount: data.count, reason: "too large"
            )
        }
        return .init(data: data, status: 200, mimeType: mime, byteCount: data.count, reason: "ok")
    }

    /// The image bytes, or `nil`. Kept for callers that have nothing to say about a failure.
    public static func data(from url: URL) async -> Data? {
        await fetch(from: url).data
    }
}
