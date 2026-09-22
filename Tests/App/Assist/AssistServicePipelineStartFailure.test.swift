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
    private var server: Server!
    private var connection: HAMockConnection!
    private var delegate: SpyAssistServiceDelegate!
    private var sut: AssistService!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
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
        Current.cachedApis = [:]
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

    private func initiateLastSubscription(with result: Result<HAData, HAError>) throws {
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.initiated(result)
    }
}

private final class SpyAssistServiceDelegate: AssistServiceDelegate {
    private(set) var errors: [(code: String, message: String)] = []

    func didReceiveEvent(_ event: AssistEvent) {}
    func didReceiveSttContent(_ content: String) {}
    func didReceiveIntentEndContent(_ content: String) {}
    func didReceiveStreamResponseChunk(_ content: String) {}
    func didReceiveGreenLightForAudioInput() {}
    func didReceiveTtsMediaUrl(_ mediaUrl: URL) {}

    func didReceiveError(code: String, message: String) {
        errors.append((code: code, message: message))
    }
}
