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
/// The access token is a snapshot, but the credential also carries the long-lived `refreshToken` and the
/// access token's `expiration`, so the widget can refresh the access token itself (a plain form-encoded
/// `POST /auth/token`) when it's near expiry — keeping complications fresh on the widget's own budget and,
/// crucially, never sending an expired token (which the server logs as invalid auth and eventually bans).
public struct WatchWidgetServerCredential: Codable, Equatable {
    /// Matches `WatchComplicationConfig.serverId`.
    public let serverId: String
    /// The server's currently reachable base URL (already resolved for internal/cloud/external).
    public let baseURL: URL
    /// Bearer token snapshot at write time.
    public let token: String
    /// Absolute expiration of `token`. The widget refreshes before this (and skips the request entirely
    /// if it can't get a valid token) rather than sending an expired token.
    public let expiration: Date
    /// Long-lived refresh token, used by the widget to mint a fresh access token via `POST /auth/token`.
    public let refreshToken: String
    /// OAuth `client_id` the refresh request must present (differs between debug and release builds).
    public let clientID: String
    /// Keychain label of the mTLS client identity, or nil when the server doesn't use a client cert.
    public let clientCertLabel: String?
    /// Raw `SecTrustCopyExceptions` blobs for self-signed / pinned server trust (empty when none).
    public let trustExceptions: [Data]

    public init(
        serverId: String,
        baseURL: URL,
        token: String,
        expiration: Date,
        refreshToken: String,
        clientID: String,
        clientCertLabel: String?,
        trustExceptions: [Data]
    ) {
        self.serverId = serverId
        self.baseURL = baseURL
        self.token = token
        self.expiration = expiration
        self.refreshToken = refreshToken
        self.clientID = clientID
        self.clientCertLabel = clientCertLabel
        self.trustExceptions = trustExceptions
    }

    /// The OAuth `client_id` to present when refreshing a token, matching the value used during
    /// onboarding (`OnboardingAuthDetails`) and by `AuthenticationRoutes`.
    public static func clientID(isDebug: Bool) -> String {
        isDebug ? "https://home-assistant.io/iOS/dev-auth" : "https://home-assistant.io/iOS"
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
