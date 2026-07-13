import Foundation
import GRDB
import HAModels
import Security

/// Lets the watch widget refresh its complication values itself, directly from Home Assistant over
/// REST, on its own WidgetKit budget — without waiting for the WatchApp to be woken, and without
/// linking the heavy networking stack (Alamofire/HAKit/PromiseKit).
///
/// It reads the per-server credential blob the WatchApp writes to the shared app group
/// (`WatchWidgetServerCredential`) and the complication configs from the mirrored GRDB database, then
/// performs a plain `URLSession` `GET /api/states/{entity}` with a small `Security`-based delegate that
/// re-applies the server's mTLS client certificate + self-signed/pinned trust from the blob.
///
/// Everything degrades gracefully: if the configs, credentials, or a live value can't be read, it
/// leaves the stored snapshot untouched and the widget renders the last known values.
enum WatchWidgetLiveFetch {
    /// Refresh the configured complication (or all, when `configuredID` is nil), updating the stored
    /// snapshot's value text in the app group. Best-effort; never throws.
    static func refresh(configuredID: String?) async {
        let configs = readConfigs()
        guard !configs.isEmpty else { return }

        let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID)
        let stored = Dictionary(
            WatchWidgetServerCredential.read(from: defaults).map { ($0.serverId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !stored.isEmpty else { return }

        // Ensure each server's access token is valid before touching `/api/states`. If it's at/near
        // expiry we refresh it ourselves (a plain `POST /auth/token`); if we can't get a valid token we
        // drop that server so we skip the request entirely rather than send an expired token — the latter
        // is what the server logs as invalid auth and eventually IP-bans.
        let (usable, persist) = await validated(stored)
        if let persist { WatchWidgetServerCredential.write(persist, to: defaults) }
        guard !usable.isEmpty else { return }

        let targets = configuredID.flatMap { id in configs.filter { $0.id == id } } ?? configs
        var updates: [String: String] = [:] // config.id -> fresh value text

        for config in targets where config.kind == .entity {
            guard let entityId = config.entityId,
                  let credential = usable[config.serverId],
                  let value = await fetchValue(config: config, entityId: entityId, credential: credential) else {
                continue
            }
            updates[config.id] = value
        }

        guard !updates.isEmpty else { return }
        applyUpdates(updates)
    }

    // MARK: - Token validity / refresh

    /// Returns the credentials that currently hold a valid access token (refreshing the ones near expiry),
    /// plus the full set to persist back to the app group when a refresh changed anything (nil = no write
    /// needed). Servers whose token can't be validated are omitted from the usable set but kept in the
    /// persisted set, so their refresh token survives for the next attempt.
    private static func validated(
        _ stored: [String: WatchWidgetServerCredential]
    ) async -> (usable: [String: WatchWidgetServerCredential], persist: [WatchWidgetServerCredential]?) {
        var usable: [String: WatchWidgetServerCredential] = [:]
        var persist = stored
        var changed = false
        for (serverId, credential) in stored {
            // Refresh a little before the real expiry so the token doesn't lapse in flight.
            if credential.expiration.addingTimeInterval(-60) > Date() {
                usable[serverId] = credential
            } else if let refreshed = await refreshedCredential(credential) {
                usable[serverId] = refreshed
                persist[serverId] = refreshed
                changed = true
            }
        }
        return (usable, changed ? Array(persist.values) : nil)
    }

    /// Mints a fresh access token via `POST /auth/token` (`grant_type=refresh_token`), returning the
    /// credential updated with the new token + expiration, or nil if the refresh fails.
    private static func refreshedCredential(
        _ credential: WatchWidgetServerCredential
    ) async -> WatchWidgetServerCredential? {
        var request = URLRequest(url: credential.baseURL.appendingPathComponent("auth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode([
            "grant_type": "refresh_token",
            "refresh_token": credential.refreshToken,
            "client_id": credential.clientID,
        ]).data(using: .utf8)

        let delegate = WatchWidgetTLSDelegate(credential: credential)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            return nil
        }
        let ttl = (json["expires_in"] as? Double) ?? (json["expires_in"] as? Int).map(Double.init) ?? 1800
        return WatchWidgetServerCredential(
            serverId: credential.serverId,
            baseURL: credential.baseURL,
            token: accessToken,
            expiration: Date(timeIntervalSinceNow: ttl),
            refreshToken: credential.refreshToken,
            clientID: credential.clientID,
            clientCertLabel: credential.clientCertLabel,
            trustExceptions: credential.trustExceptions
        )
    }

    /// `application/x-www-form-urlencoded` body: percent-encode everything but the RFC 3986 unreserved set
    /// so values like the `client_id` URL survive intact.
    private static func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    // MARK: - Fetch

    private static func fetchValue(
        config: WatchComplicationConfig,
        entityId: String,
        credential: WatchWidgetServerCredential
    ) async -> String? {
        var request = URLRequest(url: credential.baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")

        let delegate = WatchWidgetTLSDelegate(credential: credential)
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return nil
        }
        let attributes = json["attributes"] as? [String: Any] ?? [:]

        // Value + unit resolution, mirroring the WatchApp's builder (shared helpers in HAModels). The
        // value can come from an entity attribute instead of the state; the unit follows the source.
        let rawValue: String
        let resolvedUnit: String?
        if let attribute = config.valueAttribute {
            rawValue = attributes[attribute].map { String(describing: $0) } ?? state
            resolvedUnit = WatchComplicationConfig.attributeUnit(
                attribute: attribute,
                attributes: attributes,
                domain: entityId.components(separatedBy: ".").first
            )
        } else {
            rawValue = state
            resolvedUnit = attributes["unit_of_measurement"] as? String
        }
        let effectiveUnit = config.unitOverride.flatMap { $0.isEmpty ? nil : $0 } ?? resolvedUnit
        let unit = config.showsUnit() ? effectiveUnit : nil
        return format(rawValue, unit: unit, precision: config.valuePrecision)
    }

    private static func format(_ value: String, unit: String?, precision: Int?) -> String {
        var text = value
        if let precision, let number = Double(value) {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = precision
            formatter.maximumFractionDigits = precision
            text = formatter.string(from: NSNumber(value: number)) ?? value
        }
        if let unit, !unit.isEmpty {
            text += " \(unit)"
        }
        return text
    }

    // MARK: - App-group persistence

    private static func readConfigs() -> [WatchComplicationConfig] {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: WatchWidgetConstants.appGroupID) else {
            return []
        }
        let dbURL = container.appendingPathComponent("databases/App.sqlite")
        guard FileManager.default.fileExists(atPath: dbURL.path) else { return [] }
        var config = Configuration()
        config.readonly = true
        guard let queue = try? DatabaseQueue(path: dbURL.path, configuration: config) else { return [] }
        return (try? queue.read { db in
            try WatchComplicationConfig.fetchAll(db)
        }) ?? []
    }

    private static func applyUpdates(_ updates: [String: String]) {
        guard let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID),
              let data = defaults.data(forKey: WatchWidgetConstants.defaultsKey),
              var snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return
        }
        for index in snapshots.indices {
            guard let id = snapshots[index].id, let value = updates[id] else { continue }
            let name = snapshots[index].menuName ?? snapshots[index].subtitle
            snapshots[index].title = value
            snapshots[index].inlineText = [name, value].filter { !$0.isEmpty }.joined(separator: " ")
        }
        if let encoded = try? JSONEncoder().encode(snapshots) {
            defaults.set(encoded, forKey: WatchWidgetConstants.defaultsKey)
        }
    }
}

/// Minimal `URLSession` delegate that re-applies the server's TLS material from the credential blob:
/// the mTLS client identity (looked up in the shared keychain by label) and any self-signed / pinned
/// server-trust exceptions (`SecTrustCopyExceptions` blobs). Standard-TLS servers fall through to
/// default handling, so the common case needs none of this.
private final class WatchWidgetTLSDelegate: NSObject, URLSessionDelegate {
    private let credential: WatchWidgetServerCredential
    init(credential: WatchWidgetServerCredential) { self.credential = credential }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        switch space.authenticationMethod {
        case NSURLAuthenticationMethodClientCertificate:
            if let label = credential.clientCertLabel, let clientCredential = clientCredential(label: label) {
                completionHandler(.useCredential, clientCredential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        case NSURLAuthenticationMethodServerTrust:
            guard let trust = space.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            // Trust the chain if it already validates, else re-apply each stored exception in turn —
            // mirroring HANetworking's `SecurityExceptions.evaluate`.
            if SecTrustEvaluateWithError(trust, nil) {
                completionHandler(.useCredential, URLCredential(trust: trust))
                return
            }
            for exceptionData in credential.trustExceptions {
                SecTrustSetExceptions(trust, exceptionData as CFData)
                if SecTrustEvaluateWithError(trust, nil) {
                    completionHandler(.useCredential, URLCredential(trust: trust))
                    return
                }
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    /// Look up the mTLS client identity the WatchApp stored in the shared keychain (matched by label).
    private func clientCredential(label: String) -> URLCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecReturnRef as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let result else {
            return nil
        }
        // swiftlint:disable:next force_cast
        let identity = result as! SecIdentity
        var leaf: SecCertificate?
        SecIdentityCopyCertificate(identity, &leaf)
        return URLCredential(
            identity: identity,
            certificates: leaf.map { [$0] },
            persistence: .forSession
        )
    }
}
