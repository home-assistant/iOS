import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import Shared
import XCTest

/// Pipeline events reaching `AssistService` over a mock connection, and what it hands its delegate.
final class AssistServiceTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var servers: FakeServerManager!
    private var server: Server!
    private var connection: HAMockConnection!
    private var delegate: RecordingAssistServiceDelegate!
    private var sut: AssistService!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        previousDatabase = Current.database

        servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        connection.automaticallyTransitionToConnecting = false
        api.connection = connection
        Current.setCachedApi(api, for: server.identifier)

        delegate = RecordingAssistServiceDelegate()
        sut = AssistService(server: server)
        sut.delegate = delegate
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        Current.database = previousDatabase
        sut = nil
        delegate = nil
        connection = nil
        server = nil
        servers = nil
        super.tearDown()
    }

    // MARK: - Events

    func testSttEndForwardsTheRecognizedText() throws {
        try startTextRun()

        try deliver(event("stt-end", data: ["stt_output": ["text": "turn on the lights"]]))

        XCTAssertEqual(delegate.events, [.sttEnd])
        XCTAssertEqual(delegate.sttContents, ["turn on the lights"])
    }

    func testSttEndWithoutOutputForwardsEmptyText() throws {
        try startTextRun()

        try deliver(event("stt-end"))

        XCTAssertEqual(delegate.sttContents, [""])
    }

    func testIntentEndForwardsTheAnswerAndAsksToKeepListening() throws {
        try startTextRun()

        try deliver(event("intent-end", data: [
            "intent_output": [
                "conversation_id": "conversation-1",
                "continue_conversation": true,
                "response": ["speech": ["plain": ["speech": "Which room?"]]],
            ],
        ]))

        XCTAssertEqual(delegate.intentEndContents, ["Which room?"])
        XCTAssertTrue(sut.shouldStartListeningAgainAfterPlaybackEnd)

        sut.resetShouldStartListeningAgainAfterPlaybackEnd()
        XCTAssertFalse(sut.shouldStartListeningAgainAfterPlaybackEnd)
    }

    func testIntentEndWithoutAnswerForwardsEmptyText() throws {
        try startTextRun()

        try deliver(event("intent-end"))

        XCTAssertEqual(delegate.intentEndContents, [""])
        XCTAssertFalse(sut.shouldStartListeningAgainAfterPlaybackEnd)
    }

    /// The conversation id from one answer is what keeps the next prompt in the same conversation,
    /// for as long as the same pipeline is used.
    func testConversationIdIsReusedForTheSamePipelineOnly() throws {
        sut.assist(source: .text(input: "first", pipelineId: "pipeline-1", expectTTS: false))
        try deliver(event("intent-end", data: [
            "intent_output": [
                "conversation_id": "conversation-1",
                "response": ["speech": ["plain": ["speech": "ok"]]],
            ],
        ]))

        sut.assist(source: .text(input: "second", pipelineId: "pipeline-1", expectTTS: false))
        let samePipeline = try XCTUnwrap(connection.pendingSubscriptions.last)
        XCTAssertEqual(samePipeline.request.data["conversation_id"] as? String, "conversation-1")
        XCTAssertEqual(samePipeline.request.data["pipeline"] as? String, "pipeline-1")

        sut.assist(source: .audio(pipelineId: "pipeline-2", audioSampleRate: 16000, tts: true))
        let otherPipeline = try XCTUnwrap(connection.pendingSubscriptions.last)
        XCTAssertNil(otherPipeline.request.data["conversation_id"])
        XCTAssertEqual(otherPipeline.request.data["pipeline"] as? String, "pipeline-2")
    }

    func testRunsCarryTheServersDeviceId() throws {
        let deviceId = server.info.hassDeviceId
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: false))

        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        XCTAssertEqual(subscription.request.data["device_id"] as? String, deviceId)
        XCTAssertEqual(subscription.request.data["end_stage"] as? String, "intent")
    }

    func testTtsEndResolvesTheMediaPathAgainstTheServerURL() throws {
        try startTextRun()

        try deliver(event("tts-end", data: ["tts_output": ["url": "/api/tts_proxy/answer.mp3"]]))

        XCTAssertTrue(delegate.errors.isEmpty)
        let url = try XCTUnwrap(delegate.ttsURLs.first)
        XCTAssertEqual(url.host, "homeassistant.local")
        XCTAssertTrue(url.path.hasSuffix("/api/tts_proxy/answer.mp3"), url.absoluteString)
    }

    func testTtsEndWithoutMediaPathReportsAnError() throws {
        try startTextRun()

        try deliver(event("tts-end"))

        XCTAssertTrue(delegate.ttsURLs.isEmpty)
        XCTAssertEqual(delegate.errors.map(\.code), ["tts_missing_media_url"])
    }

    func testTtsEndWithoutAnActiveServerURLReportsAnError() throws {
        try startTextRun()
        sut.replaceServer(server: Server.fake(update: { info in
            info.connection.set(address: nil, for: .external)
        }))

        try deliver(event("tts-end", data: ["tts_output": ["url": "/api/tts_proxy/answer.mp3"]]))

        XCTAssertTrue(delegate.ttsURLs.isEmpty)
        XCTAssertEqual(delegate.errors.map(\.code), ["tts_no_active_url"])
    }

    func testIntentProgressStreamsChunks() throws {
        try startTextRun()

        try deliver(event("intent-progress", data: ["chat_log_delta": ["content": "Hel"]]))
        try deliver(event("intent-progress", data: ["chat_log_delta": ["content": "lo"]]))
        try deliver(event("intent-progress"))

        XCTAssertEqual(delegate.streamChunks, ["Hel", "lo", ""])
    }

    func testErrorEventIsReportedAndEndsTheRun() throws {
        try startTextRun()

        try deliver(event("error", data: ["code": "intent-failed", "message": "Unexpected error"]))

        XCTAssertEqual(delegate.errors.map(\.code), ["intent-failed"])
        XCTAssertEqual(delegate.errors.map(\.message), ["Unexpected error"])
        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
    }

    func testErrorEventWithoutDetailsGetsFallbacks() throws {
        try startTextRun()

        try deliver(event("error"))

        XCTAssertEqual(delegate.errors.map(\.code), ["-1"])
        XCTAssertEqual(delegate.errors.map(\.message), ["Unknown error"])
    }

    func testIntermediateAndUnknownEventsAreOnlyForwarded() throws {
        try startTextRun()

        for type in [
            "wake_word-start", "wake_word-end", "stt-start", "stt-vad-start", "stt-vad-end",
            "intent-start", "tts-start", "brand-new-event",
        ] {
            try deliver(event(type))
        }

        XCTAssertEqual(delegate.events, [
            .wakeWordStart, .wakeWordEnd, .sttStart, .sttVadStart, .sttVadEnd, .intentStart, .ttsStart, .unknown,
        ])
        XCTAssertTrue(delegate.errors.isEmpty)
        XCTAssertFalse(delegate.receivedGreenLight)
        XCTAssertTrue(connection.cancelledSubscriptions.isEmpty)
    }

    func testRunStartWithoutHandlerIdGivesNoGreenLight() throws {
        try startAudioRun()

        try deliver(event("run-start"))

        XCTAssertEqual(delegate.events, [.runStart])
        XCTAssertFalse(delegate.receivedGreenLight)
        sut.sendAudioData(Data([1, 2, 3]))
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    // MARK: - Audio

    func testAudioIsOnlySentOnceTheRunHasStarted() throws {
        try startAudioRun()

        sut.sendAudioData(Data([1, 2, 3]))
        sut.finishSendingAudio()
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        try deliver(event("run-start", data: ["runner_data": ["stt_binary_handler_id": 7]]))
        XCTAssertTrue(delegate.receivedGreenLight)

        let audio = Data([1, 2, 3])
        sut.sendAudioData(audio)
        let audioRequest = try XCTUnwrap(connection.pendingRequests.last)
        XCTAssertEqual(audioRequest.request.type, .sttData(.init(rawValue: 7)))
        XCTAssertEqual(audioRequest.request.data["audioData"] as? String, audio.base64EncodedString())

        sut.finishSendingAudio()
        XCTAssertEqual(connection.pendingRequests.count, 2)
        let finishRequest = try XCTUnwrap(connection.pendingRequests.last)
        XCTAssertEqual(finishRequest.request.type, .sttData(.init(rawValue: 7)))
        XCTAssertTrue(finishRequest.request.data.isEmpty)
    }

    func testRunEndStopsAudioAndCancelsTheSubscription() throws {
        try startAudioRun()
        try deliver(event("run-start", data: ["runner_data": ["stt_binary_handler_id": 1]]))

        try deliver(event("run-end"))

        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
        sut.sendAudioData(Data([9]))
        sut.finishSendingAudio()
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    // MARK: - Pipelines

    func testFetchPipelinesReturnsAndCachesTheResponse() throws {
        let database = try DatabaseQueue()
        try AssistPipelinesTable().createIfNeeded(database: database)
        Current.database = { database }
        try database.write { db in
            try AssistPipelines(serverId: server.identifier.rawValue, preferredPipeline: "old", pipelines: [])
                .insert(db)
            try AssistPipelines(serverId: "other-server", preferredPipeline: "x", pipelines: []).insert(db)
        }

        var received: PipelineResponse?
        var completed = false
        sut.fetchPipelines { response in
            received = response
            completed = true
        }

        let request = try XCTUnwrap(connection.pendingRequests.last)
        XCTAssertEqual(request.request.type, .webSocket("assist_pipeline/pipeline/list"))
        request.completion(.success(.dictionary([
            "preferred_pipeline": "pipeline-1",
            "pipelines": [["id": "pipeline-1", "name": "Home Assistant"]],
        ])))

        XCTAssertTrue(completed)
        XCTAssertEqual(received?.preferredPipeline, "pipeline-1")
        XCTAssertEqual(received?.pipelines.map(\.id), ["pipeline-1"])

        let stored = try database.read { db in try AssistPipelines.fetchAll(db) }
        XCTAssertEqual(stored.count, 2)
        let cached = try XCTUnwrap(stored.first(where: { $0.serverId == server.identifier.rawValue }))
        XCTAssertEqual(cached.preferredPipeline, "pipeline-1")
        XCTAssertEqual(cached.pipelines.map(\.name), ["Home Assistant"])
    }

    func testFetchPipelinesStillAnswersWhenTheCacheCannotBeWritten() throws {
        // No table, so saving the cache fails; the caller still gets the fetched pipelines.
        let database = try DatabaseQueue()
        Current.database = { database }

        var received: PipelineResponse?
        sut.fetchPipelines { received = $0 }

        let request = try XCTUnwrap(connection.pendingRequests.last)
        request.completion(.success(.dictionary([
            "preferred_pipeline": "pipeline-1",
            "pipelines": [[String: Any]](),
        ])))

        XCTAssertEqual(received?.preferredPipeline, "pipeline-1")
    }

    func testFetchPipelinesFailureAnswersNil() throws {
        var completed = false
        var received: PipelineResponse?
        sut.fetchPipelines { response in
            received = response
            completed = true
        }

        let request = try XCTUnwrap(connection.pendingRequests.last)
        request.completion(.failure(.internal(debugDescription: "offline")))

        XCTAssertTrue(completed)
        XCTAssertNil(received)
    }

    // MARK: - AssistSource

    func testAssistSourceEquality() {
        XCTAssertEqual(
            AssistSource.text(input: "a", pipelineId: "p", expectTTS: true),
            AssistSource.text(input: "a", pipelineId: "p", expectTTS: true)
        )
        XCTAssertNotEqual(
            AssistSource.text(input: "a", pipelineId: "p", expectTTS: true),
            AssistSource.text(input: "b", pipelineId: "p", expectTTS: true)
        )
        XCTAssertEqual(
            AssistSource.audio(pipelineId: nil, audioSampleRate: 16000, tts: false),
            AssistSource.audio(pipelineId: nil, audioSampleRate: 16000, tts: false)
        )
        XCTAssertNotEqual(
            AssistSource.audio(pipelineId: nil, audioSampleRate: 16000, tts: false),
            AssistSource.audio(pipelineId: nil, audioSampleRate: 44100, tts: false)
        )
        XCTAssertNotEqual(
            AssistSource.text(input: "a", pipelineId: nil, expectTTS: false),
            AssistSource.audio(pipelineId: nil, audioSampleRate: 16000, tts: false)
        )
    }

    // MARK: - Helpers

    private func startTextRun() throws {
        sut.assist(source: .text(input: "turn on the lights", pipelineId: "pipeline-1", expectTTS: true))
        try XCTUnwrap(connection.pendingSubscriptions.last).initiated(.success(.dictionary([:])))
    }

    private func startAudioRun() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))
        try XCTUnwrap(connection.pendingSubscriptions.last).initiated(.success(.dictionary([:])))
    }

    private func event(_ type: String, data: [String: Any]? = nil) -> HAData {
        var value: [String: Any] = [
            "type": type,
            "timestamp": "2026-09-22T16:59:52.000000+00:00",
        ]
        if let data {
            value["data"] = data
        }
        return .dictionary(value)
    }

    private func deliver(_ data: HAData) throws {
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.handler(subscription.cancellable, data)
    }

    private final class RecordingAssistServiceDelegate: AssistServiceDelegate {
        private(set) var events: [AssistEvent] = []
        private(set) var sttContents: [String] = []
        private(set) var intentEndContents: [String] = []
        private(set) var streamChunks: [String] = []
        private(set) var receivedGreenLight = false
        private(set) var ttsURLs: [URL] = []
        private(set) var errors: [(code: String, message: String)] = []

        func didReceiveEvent(_ event: AssistEvent) {
            events.append(event)
        }

        func didReceiveSttContent(_ content: String) {
            sttContents.append(content)
        }

        func didReceiveIntentEndContent(_ content: String) {
            intentEndContents.append(content)
        }

        func didReceiveStreamResponseChunk(_ content: String) {
            streamChunks.append(content)
        }

        func didReceiveGreenLightForAudioInput() {
            receivedGreenLight = true
        }

        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {
            ttsURLs.append(mediaUrl)
        }

        func didReceiveError(code: String, message: String) {
            errors.append((code: code, message: message))
        }
    }
}
