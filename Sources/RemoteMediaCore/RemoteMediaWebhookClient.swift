import Foundation

/// Posts the `mobile_app` webhook requests Remote Now Playing needs: a `call_service` per user
/// action, and the registration and dismissal that tell Home Assistant which session to push to.
///
/// Deliberately the whole networking story for the extension: no HAKit, no WebSocket, no OAuth
/// token and no entity-state round trip, because the process has a 6144 KB ledger. The host app
/// prepared the candidate URLs and the secret, so this only picks, seals and sends.
public struct RemoteMediaWebhookClient: Sendable {
    public enum ClientError: Error, Equatable {
        case noTransportContext
        case noUsableURL
        case unacceptableStatus(code: Int)
        case invalidResponse
        case unencodablePayload
    }

    /// How long a system media control may wait before the command reports failure.
    public static let timeout: TimeInterval = 10

    /// Statuses that mean the request was turned away before Home Assistant could act on it, so
    /// trying the next route cannot repeat an action. Deliberately narrow: `400` is absent because
    /// it means the server read the payload and refused it, which every route would.
    static let provesNonDelivery: Set<Int> = [401, 403, 404, 405, 410]

    public typealias Perform = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    public typealias EndBurst = @Sendable () -> Void

    private enum FallbackPolicy: Equatable {
        /// Registration, dismissal and reads are safe to repeat with the same payload.
        case idempotent
        /// A service call may only move to another route when no HTTP request could have arrived.
        case beforeDeliveryOnly
    }

    private let perform: Perform
    private let finish: EndBurst

    /// Uses one session for a command and its read-backs; call `endBurst()` when they are done.
    public init() {
        let transport = RemoteMediaWebhookTransport()
        self.perform = { try await transport.perform($0) }
        self.finish = { transport.invalidate() }
    }

    public init(perform: @escaping Perform, endBurst: @escaping EndBurst = {}) {
        self.perform = perform
        self.finish = endBurst
    }

    /// Releases the connection this command's requests shared.
    public func endBurst() {
        finish()
    }

    public func send(
        _ command: RemoteMediaCommand,
        value: Double? = nil,
        selection: RemoteMediaSelection,
        context: RemoteMediaTransportContext
    ) async throws {
        // An old system callback must never reach a player the user has stopped following.
        guard context.selection == selection else { throw RemoteMediaError.noLongerFollowing }
        guard !context.webhookURLs.isEmpty else { throw ClientError.noUsableURL }

        let call = try RemoteMediaServiceCall(command: command, entityId: selection.entityId, value: value)
        let body = try Self.body(for: call, secret: context.secret)

        try await post(
            body,
            candidates: context.webhookURLs,
            describing: call.service,
            fallbackPolicy: .beforeDeliveryOnly
        )
    }

    /// Tells Home Assistant which APNs token this session's Now Playing updates should be
    /// addressed to, so the server can refresh the card while nothing of ours is running.
    ///
    /// A success here proves the request was accepted, not that the server understood it: a Home
    /// Assistant without the matching Core support answers an unknown webhook type with an empty
    /// 200. Capability is never inferred from the reply — see `RemoteMediaSessionRegistrar`.
    public func register(
        _ registration: RemoteMediaSessionRegistration,
        context: RemoteMediaTransportContext
    ) async throws {
        // The same protection the commands have: a context belonging to a player the user has
        // since stopped following must not be used to register a different session's token.
        // Checked against the selection the payload names rather than against the session
        // identifier, which is Apple's and carries no structure this code should depend on.
        guard context.selection.serverId == registration.serverId,
              context.selection.entityId == registration.entityId else { throw RemoteMediaError.noLongerFollowing }
        try await post(
            Self.body(
                type: RemoteMediaSessionRegistration.webhookType,
                data: Self.payload(registration),
                secret: context.secret
            ),
            candidates: context.webhookURLs,
            describing: RemoteMediaSessionRegistration.webhookType,
            fallbackPolicy: .idempotent
        )
    }

    /// Tells Home Assistant that a Follow relationship is over, so the token registered for it is
    /// dropped rather than pushed to until APNs rejects it.
    public func dismiss(
        _ dismissal: RemoteMediaSessionDismissal,
        serverId: String,
        context: RemoteMediaTransportContext
    ) async throws {
        // A dismissal names a relationship, not a player, so the thing worth checking is that the
        // transport belongs to the server holding it. A retry rebuilds its routes from the server
        // as configured now, and the followed player may well have changed since.
        guard context.selection.serverId == serverId else { throw RemoteMediaError.noLongerFollowing }
        try await post(
            Self.body(
                type: RemoteMediaSessionDismissal.webhookType,
                data: Self.payload(dismissal),
                secret: context.secret
            ),
            candidates: context.webhookURLs,
            describing: RemoteMediaSessionDismissal.webhookType,
            fallbackPolicy: .idempotent
        )
    }

    /// Posts one body to the first endpoint that will take it.
    ///
    /// Shared by every request the extension makes, so a command, a registration and a dismissal
    /// all get the same cloudhook/external/internal ordering and the same rule about which failures
    /// are worth trying the next route for.
    @discardableResult
    private func post(
        _ body: [String: Any],
        candidates: [URL],
        describing label: String,
        fallbackPolicy: FallbackPolicy
    ) async throws -> Data {
        guard !candidates.isEmpty else { throw ClientError.noUsableURL }
        var lastError: Error = ClientError.noUsableURL
        for (index, url) in candidates.enumerated() {
            try Task.checkCancellation()
            do {
                let data = try await post(body, to: url)
                RemoteMediaLog.logger.info(
                    "sent \(label, privacy: .public) candidate=\(index, privacy: .public)"
                )
                return data
            } catch {
                // `URLSession` commonly surfaces task cancellation as `URLError.cancelled`.
                // Checking the parent task first preserves structured cancellation and, more
                // importantly, prevents a cancelled request from moving to another route.
                try Task.checkCancellation()
                lastError = error
                guard Self.shouldTryNextCandidate(after: error, policy: fallbackPolicy) else { throw error }
                RemoteMediaLog.logger.debug(
                    "webhook candidate \(index, privacy: .public) failed, trying next"
                )
            }
        }
        throw lastError
    }

    /// Reads the followed player's state back through `render_template`.
    ///
    /// The same encrypted webhook the commands use — no bearer token, no WebSocket, no entity-state
    /// API of our own — because the extension has a 6144 KB ledger to stay inside.
    public func readState(
        selection: RemoteMediaSelection,
        context: RemoteMediaTransportContext
    ) async throws -> RemoteMediaStateReadback {
        guard context.selection == selection else { throw RemoteMediaError.noLongerFollowing }
        // The entity id is interpolated into a Jinja template the server executes, so it is
        // checked here as well as where it was chosen: this selection may have been persisted by
        // a build that only checked the domain prefix.
        guard RemoteMediaEntityId.isValid(selection.entityId) else {
            throw RemoteMediaError.invalidSelection
        }

        let data: [String: Any] = [
            RemoteMediaStateTemplate.resultKey: [
                "template": RemoteMediaStateTemplate.template(entityId: selection.entityId),
            ],
        ]
        let response = try await post(
            Self.body(type: "render_template", data: data, secret: context.secret),
            candidates: context.webhookURLs,
            describing: "render_template",
            fallbackPolicy: .idempotent
        )
        let object = try Self.responseObject(from: response, secret: context.secret)
        guard let dictionary = object as? [String: Any],
              let rendered = dictionary[RemoteMediaStateTemplate.resultKey] else {
            return .unreadable
        }
        return RemoteMediaStateTemplate.readback(from: rendered, serverId: selection.serverId)
    }

    /// The request body: sealed when the registration has a secret, plain otherwise. Matches what
    /// `WatchWebhookClient` and `WebhookRequest` send, so HA Core sees one wire format.
    static func body(for call: RemoteMediaServiceCall, secret: [UInt8]?) throws -> [String: Any] {
        try body(type: "call_service", data: call.webhookData, secret: secret)
    }

    static func body(type: String, data: Any, secret: [UInt8]?) throws -> [String: Any] {
        var body: [String: Any] = ["type": type]
        if let secret {
            body["encrypted"] = true
            body["encrypted_data"] = try WebhookSecretBox.seal(data, secret: secret)
        } else {
            body["data"] = data
        }
        return body
    }

    /// A `Codable` payload as the JSON object the envelope carries.
    ///
    /// Round-tripped through `JSONEncoder` on purpose: the payload types' `CodingKeys` stay the one
    /// description of the wire names, rather than being restated as string literals here.
    static func payload(_ value: some Encodable) throws -> [String: Any] {
        let encoded = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
            throw ClientError.unencodablePayload
        }
        return object
    }

    /// The response's JSON, unsealed when the server encrypted it.
    static func responseObject(from data: Data, secret: [UInt8]?) throws -> Any {
        guard !data.isEmpty else { return [:] }
        let object = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
        guard let dictionary = object as? [String: Any],
              let encoded = dictionary["encrypted_data"] as? String else { return object }
        guard let secret else { return object }
        return try WebhookSecretBox.open(encoded, secret: secret)
    }

    /// Only a candidate that failed in a way the next endpoint could plausibly survive is retried,
    /// so a rejected payload does not get replayed against every URL.
    private static func shouldTryNextCandidate(after error: Error, policy: FallbackPolicy) -> Bool {
        if error is CancellationError { return false }
        switch error {
        case let ClientError.unacceptableStatus(code):
            // A gateway failure is safe to replay only for idempotent payloads: the gateway may
            // have lost Home Assistant's response after a service call already executed.
            if policy == .idempotent {
                return code == 502 || code == 503 || code == 504
            }
            // For a service call the status has to *prove* Home Assistant never ran the service,
            // because replaying next, seek or volume could apply the action twice. A gateway 5xx
            // does not prove it. These do: they are the route refusing to carry the request at
            // all, which is exactly what a cloudhook returns once it has been deleted — and
            // without this, a stale cloudhook (tried first) fails every command on the card while
            // the external and internal routes behind it would have worked.
            return Self.provesNonDelivery.contains(code)
        case let error as URLError:
            guard error.code != .cancelled else { return false }
            if policy == .idempotent { return true }
            // These failures happen before an HTTP request can reach Home Assistant. Timeouts,
            // connection loss and response decoding are deliberately absent because delivery is
            // ambiguous and replaying Next, seek or volume could apply the action twice.
            return [
                .cannotFindHost,
                .dnsLookupFailed,
                .cannotConnectToHost,
                .secureConnectionFailed,
            ].contains(error.code)
        default:
            return false
        }
    }

    @discardableResult
    private func post(_ body: [String: Any], to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (data, response) = try await perform(request)
        guard (200 ..< 300).contains(response.statusCode) else {
            throw ClientError.unacceptableStatus(code: response.statusCode)
        }
        return data
    }
}
