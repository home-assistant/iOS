import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// A pipeline the backend refuses to start — an unavailable STT provider is the common one — fails
/// as the subscription's *initial result*, not as a pipeline `error` event. That result used to be
/// dropped, so the run produced nothing at all: on the watch the session sat on its spinner until
/// the extended runtime session expired, with no indication of what went wrong. These cover that
/// the rejection is reported as an Assist error instead.
final class AssistServicePipelineStartFailureTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var server: Server!
    private var connection: HAMockConnection!
    private var delegate: SpyAssistServiceDelegate!
    private var sut: AssistService!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
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
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        sut = nil
        delegate = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    /// The exact failure seen from the watch: the only pipeline on the server is preferred, and its
    /// speech-to-text engine is not loaded on the instance.
    func testVoiceRunRejectedForMissingSttProviderReportsError() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))

        try initiateLastSubscription(with: .failure(.external(.init(
            code: "stt-provider-missing",
            message: "No speech-to-text provider for: stt.home_assistant_cloud"
        ))))

        XCTAssertEqual(delegate.errors.count, 1)
        XCTAssertEqual(delegate.errors.first?.code, "stt-provider-missing")
        XCTAssertEqual(
            delegate.errors.first?.message,
            "No speech-to-text provider for: stt.home_assistant_cloud"
        )
        // HAKit re-sends a still-registered subscription on every reconnect, so a run the server
        // already refused has to be torn down or it reports the same failure again and again.
        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
    }

    /// The prompt flow shares the same subscription, so it has to surface the same rejection.
    func testTextRunRejectedReportsError() throws {
        sut.assist(source: .text(input: "turn off the lights", pipelineId: "pipeline-1", expectTTS: true))

        try initiateLastSubscription(with: .failure(.external(.init(
            code: "pipeline-not-found",
            message: "Pipeline not found"
        ))))

        XCTAssertEqual(delegate.errors.count, 1)
        XCTAssertEqual(delegate.errors.first?.code, "pipeline-not-found")
    }

    /// A non-server-side failure has no code to forward, so it gets a generic one rather than being
    /// swallowed for lack of a better label.
    func testInternalFailureIsReportedWithGenericCode() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))

        try initiateLastSubscription(with: .failure(.internal(debugDescription: "socket died")))

        XCTAssertEqual(delegate.errors.count, 1)
        XCTAssertEqual(delegate.errors.first?.code, "pipeline_run_failed")
        XCTAssertEqual(delegate.errors.first?.message, "socket died")
    }

    /// A pipeline that starts normally must stay silent — the error path is only for rejections.
    func testSuccessfulStartReportsNoError() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))

        try initiateLastSubscription(with: .success(.dictionary([:])))

        XCTAssertTrue(delegate.errors.isEmpty)
        XCTAssertTrue(connection.cancelledSubscriptions.isEmpty)
    }

    /// A run that does start keeps delivering pipeline events to the same subscription, so the
    /// event handler still has to reach `handleAssistEvent` after the `initiated` handler was added
    /// alongside it.
    func testVoiceRunThatStartsDeliversEventsToTheHandler() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))

        try initiateLastSubscription(with: .success(.dictionary([:])))
        try deliverToLastSubscription(runStartEvent)

        XCTAssertEqual(delegate.events, [.runStart])
        XCTAssertTrue(delegate.receivedGreenLight, "run-start carries the id audio upload needs")
    }

    /// The prompt flow shares that handler, so it has to keep delivering events too.
    func testTextRunThatStartsDeliversEventsToTheHandler() throws {
        sut.assist(source: .text(input: "turn off the lights", pipelineId: nil, expectTTS: true))

        try initiateLastSubscription(with: .success(.dictionary([:])))
        try deliverToLastSubscription(runStartEvent)

        XCTAssertEqual(delegate.events, [.runStart])
    }

    /// `run-start` is the first event of a healthy run and the one that hands over the binary
    /// handler id, so it exercises the handler and the green-light path in one go.
    private var runStartEvent: HAData {
        .dictionary([
            "type": "run-start",
            "timestamp": "2026-09-22T16:59:52.000000+00:00",
            "data": ["runner_data": ["stt_binary_handler_id": 1]],
        ])
    }

    private func initiateLastSubscription(with result: Result<HAData, HAError>) throws {
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.initiated(result)
    }

    private func deliverToLastSubscription(_ data: HAData) throws {
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.handler(subscription.cancellable, data)
    }

    private final class SpyAssistServiceDelegate: AssistServiceDelegate {
        private(set) var errors: [(code: String, message: String)] = []
        private(set) var events: [AssistEvent] = []
        private(set) var receivedGreenLight = false

        func didReceiveSttContent(_ content: String) {}
        func didReceiveIntentEndContent(_ content: String) {}
        func didReceiveStreamResponseChunk(_ content: String) {}
        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {}

        func didReceiveEvent(_ event: AssistEvent) {
            events.append(event)
        }

        func didReceiveGreenLightForAudioInput() {
            receivedGreenLight = true
        }

        func didReceiveError(code: String, message: String) {
            errors.append((code: code, message: message))
        }
    }
}
