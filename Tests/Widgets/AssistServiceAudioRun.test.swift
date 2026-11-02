@testable import HomeAssistant

import Foundation
import GRDB
import HAKit
@testable import Shared
import SharedTesting
import Testing

/// A voice run through `AssistService`: the pipeline's go-ahead for audio, the audio chunks and the
/// end-of-audio marker sent on its binary handler, and the bookkeeping around a run.
///
/// `.isolatedEnvironment`: the server, API cache and database are installed per test, and the stub
/// connection delivers the pipeline's events on the test's own task.
@Suite(.isolatedEnvironment)
struct AssistServiceAudioRunTests {
    @Test func audioIsStreamedOnTheHandlerThePipelineGrants() throws {
        let (server, connection) = try install(subscriptions: { _ in
            (.success(.empty), [
                Self.event("run-start", ["runner_data": ["stt_binary_handler_id": 7, "timeout": 300]]),
                Self.event("stt-vad-start", [:]),
            ])
        })
        let delegate = RecordingDelegate()
        let service = AssistService(server: server)
        service.delegate = delegate

        // Nothing goes out before the pipeline hands over a binary handler.
        service.sendAudioData(Data([0x01]))
        service.finishSendingAudio()
        #expect(connection.sent.isEmpty)

        service.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))
        #expect(delegate.greenLights == 1)
        #expect(delegate.errors.isEmpty)
        service.sendAudioData(Data([0x01, 0x02]))
        service.finishSendingAudio()
        #expect(connection.sent.count == 2)
        #expect(connection.sent.first?.data["audioData"] as? String == Data([0x01, 0x02]).base64EncodedString())

        service.cancelRun()
        service.sendAudioData(Data([0x03]))
        #expect(connection.sent.count == 2)
        #expect(connection.subscriptions.count == 1)
    }

    @Test func aRunCanMoveToAnotherServerAndResetItsFollowUp() throws {
        let (server, _) = try install(subscriptions: { _ in
            (.success(.empty), [Self.event("intent-end", ["intent_output": [
                "continue_conversation": true,
                "response": ["speech": ["plain": ["speech": "Anything else?"]]],
            ]])])
        })
        let delegate = RecordingDelegate()
        let service = AssistService(server: server)
        service.delegate = delegate
        service.assist(source: .text(input: "Hi", pipelineId: nil, expectTTS: false))
        #expect(delegate.intentEnds == ["Anything else?"])
        #expect(service.shouldStartListeningAgainAfterPlaybackEnd)
        service.resetShouldStartListeningAgainAfterPlaybackEnd()
        #expect(!service.shouldStartListeningAgainAfterPlaybackEnd)

        // A server the app can't reach right now never gets the prompt.
        let offline = Server.fake { info in info.connection.set(address: nil, for: .external) }
        service.replaceServer(server: offline)
        service.assist(source: .text(input: "Hi", pipelineId: nil, expectTTS: false))
        #expect(delegate.intentEnds.count == 1)
    }

    /// Fetched pipelines are handed back even when the cache can't store them.
    @Test func fetchedPipelinesSurviveAFailedCacheWrite() async throws {
        let (server, _) = try install(respond: { request in
            request.type.command == "assist_pipeline/pipeline/list"
                ? .success(HAData(value: [
                    "preferred_pipeline": "cloud",
                    "pipelines": [["id": "cloud", "name": "Cloud"]],
                ]))
                : .failure(widgetStubUnexpected)
        })
        let broken = try DatabaseQueue()
        Current.database = { broken }
        let service = AssistService(server: server)
        let response: PipelineResponse? = await withCheckedContinuation { continuation in
            service.fetchPipelines { continuation.resume(returning: $0) }
        }
        #expect(response?.pipelines.map(\.id) == ["cloud"])
    }

    // MARK: - Helpers

    private static func event(_ type: String, _ data: [String: Any]) -> HAData {
        HAData(value: ["type": type, "timestamp": "2026-01-01T00:00:00.000000+00:00", "data": data])
    }

    private func install(
        respond: @escaping WidgetStubConnection.Responder = { _ in .success(.empty) },
        subscriptions: @escaping WidgetStubConnection.SubscriptionResponder = { _ in (nil, []) }
    ) throws -> (Server, WidgetStubConnection) {
        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        Current.database = { database }
        let servers = FakeServerManager()
        let server = servers.add(identifier: .init(rawValue: "assist-\(UUID().uuidString)"), serverInfo: .fake())
        Current.servers = servers
        let connection = WidgetStubConnection(respond: respond, subscriptions: subscriptions)
        let api = HomeAssistantAPI(server: server)
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)
        return (server, connection)
    }

    private final class RecordingDelegate: AssistServiceDelegate {
        private(set) var greenLights = 0
        private(set) var errors: [String] = []
        private(set) var intentEnds: [String] = []

        func didReceiveEvent(_ event: AssistEvent) {}

        func didReceiveSttContent(_ content: String) {}

        func didReceiveIntentEndContent(_ content: String) {
            intentEnds.append(content)
        }

        func didReceiveStreamResponseChunk(_ content: String) {}

        func didReceiveGreenLightForAudioInput() {
            greenLights += 1
        }

        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {}

        func didReceiveError(code: String, message: String) {
            errors.append(code)
        }
    }
}
