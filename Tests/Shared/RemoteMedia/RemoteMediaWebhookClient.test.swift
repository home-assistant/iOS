import Foundation
@testable import Shared
import Testing

struct RemoteMediaWebhookClientTests {
    private let selection = RemoteMediaSelection(serverId: "home", entityId: "media_player.speaker")
    private let secret: [UInt8] = Array(repeating: 7, count: 32)

    private func context(urls: [String], secret: [UInt8]? = nil) -> RemoteMediaTransportContext {
        .init(selection: selection, webhookURLs: urls.compactMap { URL(string: $0) }, secret: secret)
    }

    /// Records what was sent and answers with the given statuses in order.
    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        var statuses: [Int]
        var errors: [Int: Error] = [:]
        init(statuses: [Int]) { self.statuses = statuses }

        var perform: RemoteMediaWebhookClient.Perform {
            { [self] request in
                let index = requests.count
                requests.append(request)
                if let error = errors[index] { throw error }
                let code = index < statuses.count ? statuses[index] : 200
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: code, httpVersion: nil, headerFields: nil
                )!
                return (Data(), response)
            }
        }
    }

    private func decodedBody(of request: URLRequest) throws -> [String: Any] {
        let httpBody = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: httpBody)
        return try #require(object as? [String: Any])
    }

    @Test func plaintextPayloadWhenRegistrationHasNoSecret() async throws {
        let recorder = Recorder(statuses: [200])
        try await RemoteMediaWebhookClient(perform: recorder.perform)
            .send(.pause, selection: selection, context: context(urls: ["https://example.com/api/webhook/abc"]))

        let request = try #require(recorder.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://example.com/api/webhook/abc")
        let body = try decodedBody(of: request)
        #expect(body["type"] as? String == "call_service")
        #expect(body["encrypted"] == nil)
        let data = try #require(body["data"] as? [String: Any])
        #expect(data["domain"] as? String == "media_player")
        #expect(data["service"] as? String == "media_pause")
    }

    @Test func payloadIsSealedWhenRegistrationHasASecret() async throws {
        let recorder = Recorder(statuses: [200])
        try await RemoteMediaWebhookClient(perform: recorder.perform).send(
            .next,
            selection: selection,
            context: context(urls: ["https://example.com/api/webhook/abc"], secret: secret)
        )

        let request = try #require(recorder.requests.first)
        let body = try decodedBody(of: request)
        #expect(body["encrypted"] as? Bool == true)
        #expect(body["data"] == nil)
        let encoded = try #require(body["encrypted_data"] as? String)
        // The sealed payload must still be exactly what Home Assistant expects to find inside.
        let plaintext = try WebhookSecretBox.open(encoded, secret: secret)
        let opened = try #require(plaintext as? [String: Any])
        #expect(opened["service"] as? String == "media_next_track")
        // And the ciphertext must not leak the entity in the clear.
        #expect(!encoded.contains("media_player.speaker"))
    }

    @Test func staleSelectionCannotCommandAPreviouslyFollowedPlayer() async {
        let recorder = Recorder(statuses: [200])
        let other = RemoteMediaSelection(serverId: "home", entityId: "media_player.other")
        await #expect(throws: RemoteMediaError.noLongerFollowing) {
            try await RemoteMediaWebhookClient(perform: recorder.perform)
                .send(.play, selection: other, context: context(urls: ["https://example.com/api/webhook/abc"]))
        }
        #expect(recorder.requests.isEmpty)
    }

    @Test func noConfiguredURLFails() async {
        let recorder = Recorder(statuses: [])
        await #expect(throws: RemoteMediaWebhookClient.ClientError.noUsableURL) {
            try await RemoteMediaWebhookClient(perform: recorder.perform)
                .send(.play, selection: selection, context: context(urls: []))
        }
    }

    @Test func cloudhookOutageFallsBackToTheNextCandidate() async throws {
        let recorder = Recorder(statuses: [503, 200])
        try await RemoteMediaWebhookClient(perform: recorder.perform).send(
            .play,
            selection: selection,
            context: context(urls: [
                "https://cloud.example.com/hook",
                "https://external.example.com/api/webhook/abc",
            ])
        )
        #expect(recorder.requests.count == 2)
        #expect(recorder.requests.last?.url?.host == "external.example.com")
    }

    @Test func stateReadbackFallsBackToTheNextCandidate() async throws {
        let recorder = Recorder(statuses: [503, 200])
        let readback = try await RemoteMediaWebhookClient(perform: recorder.perform).readState(
            selection: selection,
            context: context(urls: [
                "https://cloud.example.com/hook",
                "https://external.example.com/api/webhook/abc",
            ])
        )

        #expect(readback == .unreadable)
        #expect(recorder.requests.count == 2)
        #expect(recorder.requests.last?.url?.host == "external.example.com")
        let body = try decodedBody(of: #require(recorder.requests.last))
        #expect(body["type"] as? String == "render_template")
    }

    @Test func unreachableCandidateFallsBackButRejectedPayloadDoesNot() async {
        let transportFailure = Recorder(statuses: [200, 200])
        transportFailure.errors[0] = URLError(.cannotConnectToHost)
        await #expect(throws: Never.self) {
            try await RemoteMediaWebhookClient(perform: transportFailure.perform).send(
                .play,
                selection: selection,
                context: context(urls: ["https://a.example.com/h", "https://b.example.com/h"])
            )
        }
        #expect(transportFailure.requests.count == 2)

        // A 400 means the server understood and refused; replaying it everywhere helps nobody.
        let rejected = Recorder(statuses: [400, 200])
        await #expect(throws: RemoteMediaWebhookClient.ClientError.unacceptableStatus(code: 400)) {
            try await RemoteMediaWebhookClient(perform: rejected.perform).send(
                .play,
                selection: selection,
                context: context(urls: ["https://a.example.com/h", "https://b.example.com/h"])
            )
        }
        #expect(rejected.requests.count == 1)
    }

    @Test func everyCandidateFailingSurfacesTheLastError() async {
        let recorder = Recorder(statuses: [503, 503])
        await #expect(throws: RemoteMediaWebhookClient.ClientError.unacceptableStatus(code: 503)) {
            try await RemoteMediaWebhookClient(perform: recorder.perform).send(
                .play,
                selection: selection,
                context: context(urls: ["https://a.example.com/h", "https://b.example.com/h"])
            )
        }
        #expect(recorder.requests.count == 2)
    }

    @Test func oneUserActionSendsExactlyOneRequest() async throws {
        let recorder = Recorder(statuses: [200])
        try await RemoteMediaWebhookClient(perform: recorder.perform).send(
            .togglePlayPause,
            selection: selection,
            context: context(urls: ["https://a.example.com/h", "https://b.example.com/h"])
        )
        // No entity-state GET beforehand, and no attempt on the remaining candidate.
        #expect(recorder.requests.count == 1)
    }
}
