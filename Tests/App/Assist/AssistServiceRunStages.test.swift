import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Every caller — in-app Assist, the watch, CarPlay — starts its runs through `AssistService`, so it
/// is where a run is kept from asking the cached pipeline for a stage the backend would refuse.
final class AssistServiceRunStagesTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var servers: FakeServerManager!
    private var database: DatabaseQueue!
    private var server: Server!
    private var connection: HAMockConnection!
    private var delegate: SpyAssistServiceDelegate!
    private var sut: AssistService!

    private let voicePipeline = Pipeline(id: "voice", name: "Voice", sttEngine: "stt.cloud", ttsEngine: "tts.cloud")
    private let textOnlyPipeline = Pipeline(
        conversationEngine: "conversation.google_ai",
        id: "text",
        name: "Gemini Nederlands (tekst)"
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        previousDatabase = Current.database

        let database = try DatabaseQueue(path: ":memory:")
        try AssistPipelinesTable().createIfNeeded(database: database)
        self.database = database
        Current.database = { database }

        servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api

        delegate = SpyAssistServiceDelegate()
        sut = AssistService(server: server)
        sut.delegate = delegate
    }

    override func tearDown() {
        Current.database = previousDatabase
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        sut = nil
        delegate = nil
        connection = nil
        server = nil
        servers = nil
        database = nil
        super.tearDown()
    }

    /// A cache whose pipeline has every stage asked for needs no confirming: the run starts at once.
    func testRunOnPipelineWithEveryStageStartsWithoutRefreshing() throws {
        try cachePipelines(preferred: voicePipeline.id)

        sut.assist(source: .audio(pipelineId: voicePipeline.id, audioSampleRate: 16000, tts: true))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        let data = try lastRunData()
        XCTAssertEqual(data["start_stage"] as? String, "stt")
        XCTAssertEqual(data["end_stage"] as? String, "tts")
    }

    /// Without a cache there is nothing to check against, so the run goes out as asked.
    func testRunWithoutCachedPipelinesIsSentAsAsked() throws {
        sut.assist(source: .audio(pipelineId: "unknown", audioSampleRate: 16000, tts: true))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        let data = try lastRunData()
        XCTAssertEqual(data["start_stage"] as? String, "stt")
        XCTAssertEqual(data["end_stage"] as? String, "tts")
    }

    /// A cache that cannot be read counts as no cache at all: the run goes out as asked.
    func testUnreadableCacheIsSentAsAsked() throws {
        let emptyDatabase = try DatabaseQueue(path: ":memory:")
        Current.database = { emptyDatabase }

        sut.assist(source: .audio(pipelineId: voicePipeline.id, audioSampleRate: 16000, tts: true))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "tts")
    }

    /// The reported hang: a text-only pipeline asked for TTS. Once the server confirms it has no TTS
    /// engine, the run ends at `intent`.
    func testTextRunOnPipelineWithoutTextToSpeechEndsAtIntent() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: textOnlyPipeline.id, expectTTS: true))
        XCTAssertTrue(connection.pendingSubscriptions.isEmpty, "the run waits for the refreshed pipelines")
        try completePipelinesRefresh(with: [voicePipeline, textOnlyPipeline])

        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "intent")
    }

    /// "Preferred" sends no pipeline id, so the capabilities checked are the preferred pipeline's.
    func testTextRunOnPreferredPipelineWithoutTextToSpeechEndsAtIntent() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: nil, expectTTS: true))
        try completePipelinesRefresh(with: [voicePipeline, textOnlyPipeline])

        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "intent")
    }

    /// The cache predates a TTS engine added on the server: the refreshed pipeline wins.
    func testTextRunOnStaleCacheUsesTheRefreshedPipeline() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)
        let upgraded = Pipeline(
            id: textOnlyPipeline.id,
            name: "Upgraded",
            sttEngine: "stt.cloud",
            ttsEngine: "tts.cloud"
        )

        sut.assist(source: .text(input: "Turn on the lights", pipelineId: textOnlyPipeline.id, expectTTS: true))
        try completePipelinesRefresh(with: [upgraded])

        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "tts")
    }

    /// The backend would refuse this run before it emitted anything, so it is not sent at all and the
    /// caller hears why — on the watch, that is what takes it off its "waiting for pipeline" spinner.
    func testVoiceRunOnPipelineWithoutSpeechToTextIsNotSentAndReportsError() throws {
        try cachePipelines(preferred: voicePipeline.id)
        let reported = expectation(description: "error reported")
        delegate.onError = { reported.fulfill() }

        sut.assist(source: .audio(pipelineId: textOnlyPipeline.id, audioSampleRate: 16000, tts: true))
        try completePipelinesRefresh(with: [voicePipeline, textOnlyPipeline])

        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
        wait(for: [reported], timeout: 2)
        XCTAssertEqual(delegate.errors.first?.code, AssistService.speechToTextUnsupportedErrorCode)
        XCTAssertEqual(delegate.errors.first?.message, AssistService.speechToTextUnsupportedMessage)
    }

    /// The fallback the error suggests only exists where Assist settings show the on-device toggle.
    func testUnsupportedSpeechToTextMessageOnlySuggestsOnDeviceWhereOffered() {
        XCTAssertEqual(
            AssistService.speechToTextUnsupportedMessage(offeringOnDeviceSpeechToText: true),
            L10n.Assist.Error.speechToTextUnsupported
        )
        XCTAssertEqual(
            AssistService.speechToTextUnsupportedMessage(offeringOnDeviceSpeechToText: false),
            L10n.Assist.Error.speechToTextUnsupportedWithoutOnDevice
        )
    }

    /// When the refresh fails the cache is the best information left.
    func testFailedRefreshFallsBackToTheCache() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: textOnlyPipeline.id, expectTTS: true))
        try XCTUnwrap(connection.pendingRequests.last).completion(.failure(.internal(debugDescription: "offline")))

        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "intent")
    }

    /// A run cancelled — or replaced by a newer one — while its pipelines were refreshing must not
    /// start once the refresh lands.
    func testRunCancelledDuringRefreshDoesNotStart() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: textOnlyPipeline.id, expectTTS: true))
        sut.cancelRun()
        try completePipelinesRefresh(with: [voicePipeline, textOnlyPipeline])

        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
    }

    /// The watch sends one prompt after another without cancelling in between: only the latest may run.
    func testNewerRunReplacesARunWaitingOnItsRefresh() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "first", pipelineId: textOnlyPipeline.id, expectTTS: true))
        sut.assist(source: .text(input: "second", pipelineId: textOnlyPipeline.id, expectTTS: true))
        XCTAssertEqual(connection.pendingRequests.count, 2)
        for request in connection.pendingRequests {
            request.completion(.success(pipelinesData([voicePipeline, textOnlyPipeline])))
        }

        XCTAssertEqual(connection.pendingSubscriptions.count, 1)
        let input = try XCTUnwrap(lastRunData()["input"] as? [String: Any])
        XCTAssertEqual(input["text"] as? String, "second")
    }

    /// The watch points the shared service at whichever server its next message is for; a run already
    /// waiting on its refresh still belongs to the server it was asked on.
    func testRunWaitingOnItsRefreshStaysOnItsServer() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)
        let otherServer = servers.addFake()
        let otherApi = HomeAssistantAPI(server: otherServer)
        let otherConnection = HAMockConnection()
        otherApi.connection = otherConnection
        Current.cachedApis[otherServer.identifier] = otherApi

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: textOnlyPipeline.id, expectTTS: true))
        sut.replaceServer(server: otherServer)
        try completePipelinesRefresh(with: [voicePipeline, textOnlyPipeline])

        XCTAssertEqual(connection.pendingSubscriptions.count, 1)
        XCTAssertTrue(otherConnection.pendingSubscriptions.isEmpty)
        XCTAssertEqual(try lastRunData()["end_stage"] as? String, "intent")
        let cachedForRunServer = AssistPipelines.cachedPipeline(
            id: textOnlyPipeline.id,
            serverId: server.identifier.rawValue
        )
        XCTAssertNotNil(cachedForRunServer, "the refreshed pipelines are cached for the server they came from")
        XCTAssertNil(AssistPipelines.cachedPipeline(id: textOnlyPipeline.id, serverId: otherServer.identifier.rawValue))
    }

    func testSourceExposesItsPipelineId() {
        XCTAssertEqual(AssistSource.text(input: "", pipelineId: "a", expectTTS: false).pipelineId, "a")
        XCTAssertEqual(AssistSource.audio(pipelineId: "b", audioSampleRate: 16000, tts: false).pipelineId, "b")
    }

    private func cachePipelines(preferred: String) throws {
        try database.write { db in
            try AssistPipelines(
                serverId: server.identifier.rawValue,
                preferredPipeline: preferred,
                pipelines: [voicePipeline, textOnlyPipeline]
            ).save(db)
        }
    }

    private func lastRunData() throws -> [String: Any] {
        try XCTUnwrap(connection.pendingSubscriptions.last).request.data
    }

    private func completePipelinesRefresh(with pipelines: [Pipeline]) throws {
        try XCTUnwrap(connection.pendingRequests.last).completion(.success(pipelinesData(pipelines)))
    }

    private func pipelinesData(_ pipelines: [Pipeline]) -> HAData {
        .init(value: [
            "preferred_pipeline": textOnlyPipeline.id,
            "pipelines": pipelines.map { pipeline -> [String: Any] in
                var data: [String: Any] = ["id": pipeline.id, "name": pipeline.name]
                data["stt_engine"] = pipeline.sttEngine
                data["tts_engine"] = pipeline.ttsEngine
                return data
            },
        ])
    }

    private final class SpyAssistServiceDelegate: AssistServiceDelegate {
        private(set) var errors: [(code: String, message: String)] = []
        var onError: (() -> Void)?

        func didReceiveEvent(_ event: AssistEvent) {}
        func didReceiveSttContent(_ content: String) {}
        func didReceiveIntentEndContent(_ content: String) {}
        func didReceiveStreamResponseChunk(_ content: String) {}
        func didReceiveGreenLightForAudioInput() {}
        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {}

        func didReceiveError(code: String, message: String) {
            errors.append((code: code, message: message))
            onError?()
        }
    }
}
