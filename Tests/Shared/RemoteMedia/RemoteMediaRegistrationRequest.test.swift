import Foundation
@testable import Shared
import Testing

/// The registration and dismissal as Home Assistant receives them.
///
/// Both go out through the same encrypted `mobile_app` envelope the commands use, and the payload
/// keys are what `homeassistant/components/mobile_app/remote_media/webhook.py` requires, so they
/// are asserted literally rather than through the Swift property names. This is one half of a
/// cross-repository contract; `tests/components/mobile_app/remote_media/test_webhook.py` asserts
/// the same bytes from the other side.
struct RemoteMediaRegistrationRequestTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
    private let secret: [UInt8] = Array(repeating: 9, count: 32)
    private let lifetime = RemoteMediaFollowLifetime(generation: "F1B7D0A2", sequence: 42)

    private func context(secret: [UInt8]? = nil) -> RemoteMediaTransportContext {
        .init(
            selection: selection,
            webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
            secret: secret
        )
    }

    private func registration(
        lifetime: RemoteMediaFollowLifetime? = nil,
        token: String = "0a1b2c3d"
    ) -> RemoteMediaSessionRegistration {
        .init(
            sessionId: selection.id,
            serverId: selection.serverId,
            entityId: selection.entityId,
            lifetime: lifetime ?? self.lifetime,
            pushToken: token
        )
    }

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        var status = 200

        var perform: RemoteMediaWebhookClient.Perform {
            { [self] request in
                requests.append(request)
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil
                )!
                return (Data(), response)
            }
        }
    }

    private func body(of request: URLRequest) throws -> [String: Any] {
        let httpBody = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: httpBody)
        return try #require(object as? [String: Any])
    }

    // MARK: - Construction

    /// The session identifier is Apple's, and the server treats it as opaque — it is echoed into
    /// the attributes that route a push and nothing else. Which server and entity the relationship
    /// is about is stated explicitly rather than left to be parsed back out of it.
    @Test func theRegistrationNamesItsServerAndEntityExplicitly() {
        let registration = registration()
        #expect(registration.sessionId == selection.id)
        #expect(registration.serverId == "home")
        #expect(registration.entityId == "media_player.speaker")
        #expect(registration.generation == "F1B7D0A2")
        #expect(registration.generationSequence == 42)
        #expect(registration.lifetime == lifetime)
        #expect(registration.schemaVersion == 1)
        #expect(RemoteMediaSessionRegistration.currentSchemaVersion == 1)
    }

    /// APNs addresses a token in lowercase hexadecimal, and `RemoteMediaPushToken.hex` is what a
    /// registration is built from rather than any other rendering of the bytes.
    @Test func theTokenIsLowercaseHexadecimal() {
        let token = RemoteMediaPushToken(Data([0x0A, 0xFF, 0x10, 0xBC]))
        #expect(token.hex == "0aff10bc")
        let registration = registration(token: token.hex)
        #expect(registration.pushToken == "0aff10bc")
        #expect(registration.pushToken == registration.pushToken.lowercased())
    }

    // MARK: - Envelope

    @Test func theRegistrationUsesTheEncryptedMobileAppEnvelope() async throws {
        let recorder = Recorder()
        try await RemoteMediaWebhookClient(perform: recorder.perform)
            .register(registration(), context: context(secret: secret))

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.com/api/webhook/abc")
        let body = try body(of: request)
        #expect(body["type"] as? String == "remote_media_session_token")
        #expect(body["encrypted"] as? Bool == true)
        #expect(body["data"] == nil)

        let sealed = try #require(body["encrypted_data"] as? String)
        // The token is the one thing in here that must not travel in the clear.
        #expect(!sealed.contains("0a1b2c3d"))
        let opened = try WebhookSecretBox.open(sealed, secret: secret)
        let payload = try #require(opened as? [String: Any])
        #expect(Set(payload.keys) == [
            "session_id",
            "server_id",
            "entity_id",
            "generation",
            "generation_sequence",
            "push_token",
            "schema_version",
        ])
        #expect(payload["session_id"] as? String == "4:homemedia_player.speaker")
        #expect(payload["server_id"] as? String == "home")
        #expect(payload["entity_id"] as? String == "media_player.speaker")
        #expect(payload["generation"] as? String == "F1B7D0A2")
        #expect(payload["generation_sequence"] as? Int == 42)
        #expect(payload["push_token"] as? String == "0a1b2c3d")
        #expect(payload["schema_version"] as? Int == 1)
    }

    @Test func theDismissalUsesTheEncryptedMobileAppEnvelope() async throws {
        let recorder = Recorder()
        try await RemoteMediaWebhookClient(perform: recorder.perform).dismiss(
            .init(sessionId: selection.id, generation: "F1B7D0A2", generationSequence: 42),
            serverId: "home",
            context: context(secret: secret)
        )

        let body = try body(of: #require(recorder.requests.first))
        #expect(body["type"] as? String == "remote_media_session_dismissed")
        #expect(body["encrypted"] as? Bool == true)
        let sealed = try #require(body["encrypted_data"] as? String)
        let opened = try WebhookSecretBox.open(sealed, secret: secret)
        let payload = try #require(opened as? [String: Any])
        // Nothing else: a dismissal names a relationship, it does not describe one. No `server_id`
        // either — the request authenticated against the server that holds the registration.
        #expect(Set(payload.keys) == ["session_id", "generation", "generation_sequence"])
        #expect(payload["session_id"] as? String == "4:homemedia_player.speaker")
        #expect(payload["generation"] as? String == "F1B7D0A2")
        #expect(payload["generation_sequence"] as? Int == 42)
    }

    /// Every key is required now, so the shape a server validates against is the same every time.
    @Test func noKeyIsEverOmitted() async throws {
        let recorder = Recorder()
        let client = RemoteMediaWebhookClient(perform: recorder.perform)
        try await client.register(
            registration(lifetime: .init(generation: "g", sequence: 1), token: "ff"),
            context: context()
        )
        let sent = try #require(recorder.requests.first)
        // Hoisted: SwiftFormat rewrites `try #require(try …)` into a macro that does not exist.
        let decoded = try body(of: sent)
        let payload = try #require(decoded["data"] as? [String: Any])
        #expect(payload.count == 7)
        #expect(payload.values.allSatisfy { !($0 is NSNull) })
    }

    /// The registration goes out over the routes the commands already use, in the same order, and
    /// carries nothing about how the server should reach APNs.
    @Test func theClientNamesNothingAboutApns() async throws {
        let recorder = Recorder()
        let context = RemoteMediaTransportContext(
            selection: selection,
            webhookURLs: [
                URL(string: "https://cloud.example.com/hook")!,
                URL(string: "https://external.example.com/api/webhook/abc")!,
            ],
            secret: nil
        )
        try await RemoteMediaWebhookClient(perform: recorder.perform)
            .register(registration(), context: context)

        let request = try #require(recorder.requests.first)
        #expect(recorder.requests.count == 1)
        #expect(request.url?.host == "cloud.example.com")
        let httpBody = try #require(request.httpBody)
        let raw = try #require(String(data: httpBody, encoding: .utf8))
        for forbidden in ["push.apple.com", "apns", "topic", "team", "key_id"] {
            #expect(!raw.lowercased().contains(forbidden))
        }
        #expect(request.allHTTPHeaderFields?["apns-topic"] == nil)
        #expect(request.allHTTPHeaderFields?["apns-push-type"] == nil)
    }

    // MARK: - Whose transport may say what

    /// A context belonging to a player the user has since stopped following must not be used to
    /// register a different session's token. Checked against the server and entity the payload
    /// names, so nothing depends on how Apple's session identifier happens to be built.
    @Test func aContextForAnotherPlayerCannotRegister() async {
        let recorder = Recorder()
        let other = RemoteMediaTransportContext(
            selection: .init(serverId: "home", entityId: "media_player.other"),
            webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
            secret: nil
        )
        await #expect(throws: RemoteMediaError.noLongerFollowing) {
            try await RemoteMediaWebhookClient(perform: recorder.perform)
                .register(registration(), context: other)
        }
        #expect(recorder.requests.isEmpty)
    }

    /// A dismissal names a relationship rather than a player, so what matters is that the
    /// transport belongs to the server holding it — a retry rebuilds its routes long after the
    /// followed player has changed.
    @Test func aDismissalTravelsOnAnyContextForTheRightServer() async throws {
        let recorder = Recorder()
        let laterSelection = RemoteMediaTransportContext(
            selection: .init(serverId: "home", entityId: "media_player.something_else"),
            webhookURLs: [URL(string: "https://example.com/api/webhook/abc")!],
            secret: nil
        )
        let dismissal = RemoteMediaSessionDismissal(
            sessionId: selection.id, generation: "F1B7D0A2", generationSequence: 42
        )
        try await RemoteMediaWebhookClient(perform: recorder.perform)
            .dismiss(dismissal, serverId: "home", context: laterSelection)
        #expect(recorder.requests.count == 1)

        // A different server is another matter: that would authenticate one server's relationship
        // against another's registration.
        await #expect(throws: RemoteMediaError.noLongerFollowing) {
            try await RemoteMediaWebhookClient(perform: recorder.perform)
                .dismiss(dismissal, serverId: "elsewhere", context: laterSelection)
        }
        #expect(recorder.requests.count == 1)
    }
}
