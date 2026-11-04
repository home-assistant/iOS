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
    /// Complications rendered entirely from static content, so there is nothing to fetch for them.
    private static let builtInIDs = [
        WatchWidgetComplicationSnapshot.placeholderID,
        WatchWidgetComplicationSnapshot.assistID,
    ]

    /// Refresh a single complication — the one the calling widget instance renders — updating its stored
    /// snapshot's value text in the app group. Best-effort; never throws.
    ///
    /// Deliberately scoped to one complication: every instance on the face runs its own
    /// `timeline(for:in:)`, so refreshing all of them here meant N instances × N complications of
    /// sequential networking inside a single extension process. The watch app's periodic refresh remains
    /// responsible for the complications that aren't currently on screen.
    static func refresh(complicationID: String?) async {
        // The built-in placeholder and Assist complications have no live value to fetch.
        guard let complicationID, !builtInIDs.contains(complicationID) else { return }

        let configs = readConfigs()
        guard let target = configs.first(where: { $0.id == complicationID }) else {
            // Either the mirrored database couldn't be read, or the face still points at a
            // complication that no longer exists (deleted, or recreated with a new id).
            WatchWidgetRefreshNotifier.notifyFinished("Skipped: no complication configured for \(complicationID)")
            return
        }
        guard claimFetchSlot(complicationID) else {
            WatchWidgetRefreshNotifier.notifyFinished(
                "Skipped \(target.displayName): fetched less than "
                    + "\(Int(WatchWidgetConstants.selfFetchThrottleInterval))s ago"
            )
            return
        }

        WatchWidgetRefreshNotifier.notifyStarted(names: [target.displayName])
        let started = Date()
        let summary = await performRefresh(configs: configs, targets: [target])
        WatchWidgetRefreshNotifier.notifyFinished(
            summary + String(format: " — total %.1fs", Date().timeIntervalSince(started))
        )
    }

    // MARK: - Throttle

    /// Serializes the throttle's read-then-write. WidgetKit can run several instances'
    /// `timeline(for:in:)` calls concurrently in one process, so checking the timestamp and recording
    /// the claim as separate steps would let them all pass together — the stampede this exists to stop.
    private static let throttleLock = NSLock()

    /// Claims this complication's fetch slot, returning false when it was fetched recently enough that
    /// another round trip would be wasted work.
    ///
    /// The claim is recorded before the request rather than after it, so a slow fetch still holds the
    /// slot against the instances reloading alongside it. Each complication gets its own defaults key:
    /// a single shared dictionary would need a read-modify-write, and concurrent claims for different
    /// complications would drop each other's timestamp.
    private static func claimFetchSlot(_ complicationID: String) -> Bool {
        throttleLock.lock()
        defer { throttleLock.unlock() }

        let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID)
        let key = WatchWidgetConstants.lastSelfFetchKeyPrefix + complicationID
        let now = Date()
        if let last = defaults?.object(forKey: key) as? Date {
            let elapsed = now.timeIntervalSince(last)
            // A negative elapsed means the clock moved backwards; treat it as stale rather than
            // blocking the fetch until the recorded date is reached.
            if elapsed >= 0, elapsed < WatchWidgetConstants.selfFetchThrottleInterval {
                return false
            }
        }
        defaults?.set(now, forKey: key)
        return true
    }

    /// The actual refresh. Returns a human-readable outcome for the developer-option notification —
    /// per complication: the fresh value and how long its fetch took, or why it failed; ignored when
    /// the option is off.
    private static func performRefresh(
        configs: [WatchComplicationConfig],
        targets: [WatchComplicationConfig]
    ) async -> String {
        guard !configs.isEmpty else { return "Failed: no complication configurations found" }

        let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID)
        let stored = Dictionary(
            WatchWidgetServerCredential.read(from: defaults).map { ($0.serverId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        guard !stored.isEmpty else { return "Failed: no server credentials stored by the watch app" }

        // Ensure each server's access token is valid before touching `/api/states`. If it's at/near
        // expiry we refresh it ourselves (a plain `POST /auth/token`); if we can't get a valid token we
        // drop that server so we skip the request entirely rather than send an expired token — the latter
        // is what the server logs as invalid auth and eventually IP-bans.
        let (usable, persist) = await validated(stored)
        if let persist { WatchWidgetServerCredential.write(persist, to: defaults) }
        guard !usable.isEmpty else {
            return "Failed: no valid access token for server(s) " + stored.keys.sorted().joined(separator: ", ")
        }

        let (updates, details, rejectedServerIds) = await fetchUpdates(targets: targets, usable: usable)
        if !rejectedServerIds.isEmpty { invalidateRejectedCredentials(rejectedServerIds, defaults: defaults) }
        if !updates.isEmpty { applyUpdates(updates, configs: configs) }

        let entityCount = targets.filter { $0.kind == .entity }.count
        var summary = "Updated \(updates.count) of \(entityCount) complication(s)"
        if !details.isEmpty { summary += "\n" + details.joined(separator: "\n") }
        return summary
    }

    /// Fetches each entity complication's live value, collecting a detail line per complication for
    /// the developer notification: the fresh value and fetch time on success, the elapsed time and
    /// cause on failure.
    private static func fetchUpdates(
        targets: [WatchComplicationConfig],
        usable: [String: WatchWidgetServerCredential]
    ) async -> (updates: [String: LiveValue], details: [String], rejectedServerIds: Set<String>) {
        var updates: [String: LiveValue] = [:] // config.id -> fresh value
        var details: [String] = []
        var rejectedServerIds: Set<String> = []
        for config in targets {
            let label = config.entityId.map { "\(config.displayName) (\($0))" } ?? config.displayName
            guard config.kind == .entity else {
                details.append("\(label): skipped — template complications can't self-fetch")
                continue
            }
            guard let entityId = config.entityId else {
                details.append("\(label): failed — no entity configured")
                continue
            }
            guard let credential = usable[config.serverId] else {
                details.append("\(label): failed — no valid credential for its server")
                continue
            }
            // Once this run saw a 401 for the server, don't send its rejected token again for the
            // remaining complications — each repeat is another invalid-auth hit toward an IP ban.
            guard !rejectedServerIds.contains(config.serverId) else {
                details.append("\(label): skipped — server rejected this run's token")
                continue
            }
            let started = Date()
            let result = await fetchValue(config: config, entityId: entityId, credential: credential)
            let elapsed = String(format: "%.1fs", Date().timeIntervalSince(started))
            if result.unauthorized {
                rejectedServerIds.insert(config.serverId)
            }
            if let value = result.value {
                updates[config.id] = value
                details.append("\(label): updated to \(value.value) in \(elapsed)")
            } else {
                details.append("\(label): failed in \(elapsed) — \(result.failure ?? "unknown reason")")
            }
        }
        return (updates, details, rejectedServerIds)
    }

    /// The server answered 401 for these servers' tokens even though their client-side expiration
    /// hadn't passed (revoked refresh token, server restored from backup, clock skew). Persist them
    /// as expired so the next run mints a fresh token via the refresh token — or skips the server
    /// entirely — instead of re-sending a token the server logs as invalid auth and, on repeats,
    /// answers with an IP ban.
    private static func invalidateRejectedCredentials(_ serverIds: Set<String>, defaults: UserDefaults?) {
        let current = WatchWidgetServerCredential.read(from: defaults)
        guard !current.isEmpty else { return }
        let updated = current.map { credential -> WatchWidgetServerCredential in
            guard serverIds.contains(credential.serverId) else { return credential }
            return WatchWidgetServerCredential(
                serverId: credential.serverId,
                baseURL: credential.baseURL,
                token: credential.token,
                expiration: .distantPast,
                refreshToken: credential.refreshToken,
                clientID: credential.clientID,
                clientCertLabel: credential.clientCertLabel,
                trustExceptions: credential.trustExceptions
            )
        }
        WatchWidgetServerCredential.write(updated, to: defaults)
    }

    /// A fresh formatted value plus the raw state and attributes, so slot formulas and gauge
    /// fractions that reference them can be re-resolved without another fetch.
    private struct LiveValue {
        let value: String
        let state: String
        let attributes: [String: Any]
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

        let session = makeSession(for: credential)
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

    /// A session bounded by `selfFetchTimeout`. Extensions get a much shorter watchdog budget than the
    /// app, so `URLSession`'s 60s request / 7-day resource defaults would let one unreachable server
    /// hold the process open until the system kills it — which reads to WidgetKit as a crashing
    /// extension and stops the reloads entirely.
    private static func makeSession(for credential: WatchWidgetServerCredential) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = WatchWidgetConstants.selfFetchTimeout
        configuration.timeoutIntervalForResource = WatchWidgetConstants.selfFetchTimeout
        // Fail fast instead of parking the request until the watch has a route to the server.
        configuration.waitsForConnectivity = false
        return URLSession(
            configuration: configuration,
            delegate: WatchWidgetTLSDelegate(credential: credential),
            delegateQueue: nil
        )
    }

    /// Fetches the entity's live state. On failure the value is nil and `failure` says why
    /// (transport error, HTTP status, malformed body), so the developer notification can report the
    /// actual cause instead of a generic "fetch failed". `unauthorized` flags an HTTP 401 — the
    /// server rejected the token despite its client-side expiration — so the caller can retire the
    /// credential instead of re-sending it.
    private static func fetchValue(
        config: WatchComplicationConfig,
        entityId: String,
        credential: WatchWidgetServerCredential
    ) async -> (value: LiveValue?, failure: String?, unauthorized: Bool) {
        var request = URLRequest(url: credential.baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(credential.token)", forHTTPHeaderField: "Authorization")

        let session = makeSession(for: credential)
        defer { session.finishTasksAndInvalidate() }

        let data: Data
        do {
            let (body, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return (nil, "no HTTP response", false) }
            guard (200 ..< 300).contains(http.statusCode) else {
                return (nil, "HTTP \(http.statusCode)", http.statusCode == 401)
            }
            data = body
        } catch {
            return (nil, error.localizedDescription, false)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return (nil, "unexpected response body", false)
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
        return (
            LiveValue(
                value: format(rawValue, unit: unit, precision: config.valuePrecision),
                state: state,
                attributes: attributes
            ),
            nil,
            false
        )
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

    private static func applyUpdates(_ updates: [String: LiveValue], configs: [WatchComplicationConfig]) {
        guard let defaults = UserDefaults(suiteName: WatchWidgetConstants.appGroupID),
              let data = defaults.data(forKey: WatchWidgetConstants.defaultsKey),
              var snapshots = try? JSONDecoder().decode([WatchWidgetComplicationSnapshot].self, from: data) else {
            return
        }
        for index in snapshots.indices {
            guard let id = snapshots[index].id, let update = updates[id] else { continue }
            let config = configs.first(where: { $0.id == id })
            // The face name (entity name), never the complication's own name — that one only labels
            // the config in lists. Resolved off the config, not the snapshot's stored strings, which
            // can be stale relative to the current config.
            let name = config?.faceName ?? snapshots[index].subtitle
            snapshots[index].title = update.value
            snapshots[index].inlineText = [name, update.value].filter { !$0.isEmpty }.joined(separator: " ")

            // Re-resolve the slot texts in place with the fresh state. Only entity complications
            // reach here, so every formula resolves on-device — no template rendering involved.
            guard let config else { continue }
            let context = ComplicationFormulaContext(
                entityName: config.faceName,
                formattedState: update.value,
                attributeValue: { update.attributes[$0].map { String(describing: $0) } }
            )
            refreshSlotTexts(in: &snapshots[index], config: config, context: context)
            refreshFractions(
                in: &snapshots[index],
                config: config,
                state: update.state,
                attributes: update.attributes
            )
        }
        if let encoded = try? JSONEncoder().encode(snapshots) {
            defaults.set(encoded, forKey: WatchWidgetConstants.defaultsKey)
        }
    }

    /// Re-resolves a snapshot's per-family slot texts against fresh entity data, leaving families
    /// without slot payloads (older snapshots) untouched.
    private static func refreshSlotTexts(
        in snapshot: inout WatchWidgetComplicationSnapshot,
        config: WatchComplicationConfig,
        context: ComplicationFormulaContext
    ) {
        for family in WatchComplicationConfig.Family.allCases {
            guard var options = snapshot.perFamily?[family.rawValue] else { continue }
            func slotText(_ slot: ComplicationSlot) -> String {
                ComplicationFormulaResolver.resolve(
                    config.formula(for: slot, family: family),
                    context: context
                )
            }
            if options.title != nil { options.title = slotText(.title) }
            if options.subtitle != nil { options.subtitle = slotText(.subtitle) }
            if options.value != nil { options.value = slotText(.value) }
            if options.bottomText != nil { options.bottomText = slotText(.bottomText) }
            snapshot.perFamily?[family.rawValue] = options
        }
    }

    /// Re-computes a snapshot's gauge fractions from the fresh entity data. Without this the value
    /// text updates but the gauge ring/bar keeps its previous position until the WatchApp's next
    /// full refresh.
    private static func refreshFractions(
        in snapshot: inout WatchWidgetComplicationSnapshot,
        config: WatchComplicationConfig,
        state: String,
        attributes: [String: Any]
    ) {
        snapshot.fraction = fraction(config: config, family: config.widgetFamily, state: state, attributes: attributes)
        for family in WatchComplicationConfig.Family.allCases {
            guard var options = snapshot.perFamily?[family.rawValue] else { continue }
            options.fraction = fraction(config: config, family: family, state: state, attributes: attributes)
            snapshot.perFamily?[family.rawValue] = options
        }
    }

    /// The gauge fill for a family, mirroring the WatchApp's snapshot builder: the gauge attribute,
    /// else the value attribute, else the state, scaled into the configured range.
    private static func fraction(
        config: WatchComplicationConfig,
        family: WatchComplicationConfig.Family,
        state: String,
        attributes: [String: Any]
    ) -> Double? {
        guard let range = config.gaugeRange(for: family), range.max > range.min else { return nil }
        let source: Any = config.gaugeAttribute(for: family).flatMap { attributes[$0] }
            ?? config.valueAttribute.flatMap { attributes[$0] }
            ?? state
        guard let raw = number(from: source) else { return nil }
        return min(max((raw - range.min) / (range.max - range.min), 0), 1)
    }

    /// Forgiving number parsing for states/attribute values, mirroring
    /// `WatchComplication.percentileNumber` (which lives in the app-only Shared target).
    private static func number(from source: Any) -> Double? {
        switch source {
        case let value as String:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            // Non-locale-aware server strings ("0.33") first, then the user's locale ("0,33").
            for locale in [Locale(identifier: "en_US_POSIX"), Locale.current] {
                formatter.locale = locale
                if let value = formatter.number(from: value)?.doubleValue {
                    return value
                }
            }
            return nil
        case let value as Int:
            return Double(value)
        case let value as Double:
            return value
        case let value as Float:
            return Double(value)
        default:
            return number(from: String(describing: source))
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
