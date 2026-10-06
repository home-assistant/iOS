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

        let servers = FakeServerManager()
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
        database = nil
        super.tearDown()
    }

    func testTextRunOnPipelineWithoutTextToSpeechEndsAtIntent() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: textOnlyPipeline.id, expectTTS: true))

        XCTAssertEqual(try lastRequestData()["end_stage"] as? String, "intent")
    }

    /// "Preferred" sends no pipeline id, so the capabilities checked are the preferred pipeline's.
    func testTextRunOnPreferredPipelineWithoutTextToSpeechEndsAtIntent() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Zeg alleen TEST", pipelineId: nil, expectTTS: true))

        XCTAssertEqual(try lastRequestData()["end_stage"] as? String, "intent")
    }

    func testTextRunOnPipelineWithTextToSpeechEndsAtTTS() throws {
        try cachePipelines(preferred: textOnlyPipeline.id)

        sut.assist(source: .text(input: "Turn on the lights", pipelineId: voicePipeline.id, expectTTS: true))

        XCTAssertEqual(try lastRequestData()["end_stage"] as? String, "tts")
    }

    func testVoiceRunOnPipelineWithSpeechToTextStarts() throws {
        try cachePipelines(preferred: voicePipeline.id)

        sut.assist(source: .audio(pipelineId: voicePipeline.id, audioSampleRate: 16000, tts: true))

        let data = try lastRequestData()
        XCTAssertEqual(data["start_stage"] as? String, "stt")
        XCTAssertEqual(data["end_stage"] as? String, "tts")
        XCTAssertTrue(delegate.errors.isEmpty)
    }

    /// The backend would refuse this run before it emitted anything, so it is not sent at all and the
    /// caller hears why — on the watch, that is what takes it off its "waiting for pipeline" spinner.
    func testVoiceRunOnPipelineWithoutSpeechToTextIsNotSentAndReportsError() throws {
        try cachePipelines(preferred: voicePipeline.id)
        let reported = expectation(description: "error reported")
        delegate.onError = { reported.fulfill() }

        sut.assist(source: .audio(pipelineId: textOnlyPipeline.id, audioSampleRate: 16000, tts: true))

        XCTAssertTrue(connection.pendingSubscriptions.isEmpty)
        wait(for: [reported], timeout: 2)
        XCTAssertEqual(delegate.errors.first?.code, AssistService.speechToTextUnsupportedErrorCode)
        XCTAssertEqual(delegate.errors.first?.message, L10n.Assist.Error.speechToTextUnsupported)
    }

    /// Without a cache there is nothing to check against, so the run goes out as asked.
    func testRunWithoutCachedPipelinesIsSentAsAsked() throws {
        sut.assist(source: .audio(pipelineId: "unknown", audioSampleRate: 16000, tts: true))

        let data = try lastRequestData()
        XCTAssertEqual(data["start_stage"] as? String, "stt")
        XCTAssertEqual(data["end_stage"] as? String, "tts")
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

    private func lastRequestData() throws -> [String: Any] {
        try XCTUnwrap(connection.pendingSubscriptions.last).request.data
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
