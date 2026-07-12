import Foundation

/// Credentials the WatchApp hands to the watch-widget extension so the widget can self-fetch
/// complication values over REST on its own WidgetKit budget — without linking the heavy networking
/// stack (Alamofire/HAKit/PromiseKit) and without waiting for the WatchApp to be woken.
///
/// The WatchApp writes this to the shared app group whenever it refreshes complications; `WatchWidgets`
/// reads it in its timeline provider. Everything needed for an authenticated (optionally mTLS /
/// self-signed) request is captured as plain, `Codable` data so the widget can apply it with a small
/// `URLSession` delegate rather than reusing the server/connection objects.
///
/// The token is a snapshot: a widget cannot refresh an expired token, so a stale token simply makes the
/// fetch fail and the widget keeps its last-known snapshot until the WatchApp writes a fresh credential.
public struct WatchWidgetServerCredential: Codable, Equatable {
    /// Matches `WatchComplicationConfig.serverId`.
    public let serverId: String
    /// The server's currently reachable base URL (already resolved for internal/cloud/external).
    public let baseURL: URL
    /// Bearer token snapshot at write time.
    public let token: String
    /// Keychain label of the mTLS client identity, or nil when the server doesn't use a client cert.
    public let clientCertLabel: String?
    /// Raw `SecTrustCopyExceptions` blobs for self-signed / pinned server trust (empty when none).
    public let trustExceptions: [Data]

    public init(
        serverId: String,
        baseURL: URL,
        token: String,
        clientCertLabel: String?,
        trustExceptions: [Data]
    ) {
        self.serverId = serverId
        self.baseURL = baseURL
        self.token = token
        self.clientCertLabel = clientCertLabel
        self.trustExceptions = trustExceptions
    }

    /// App-group `UserDefaults` key the blob array is stored under.
    public static let defaultsKey = "watchWidgetServerCredentials"

    /// Persist the full set of per-server credentials to the shared app group. Best-effort.
    public static func write(_ credentials: [WatchWidgetServerCredential], to defaults: UserDefaults?) {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(credentials) {
            defaults.set(data, forKey: defaultsKey)
        }
    }

    /// Read the stored per-server credentials from the shared app group (empty when absent/undecodable).
    public static func read(from defaults: UserDefaults?) -> [WatchWidgetServerCredential] {
        guard let defaults, let data = defaults.data(forKey: defaultsKey),
              let credentials = try? JSONDecoder().decode([WatchWidgetServerCredential].self, from: data) else {
            return []
        }
        return credentials
    }
}
