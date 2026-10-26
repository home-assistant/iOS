import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Talking through the camera opens a microphone session of its own next to the video stream, and
/// it has to be hung up whenever the player goes away.
final class WebRTCViewPlayerViewModelTalkbackTests: XCTestCase {
    private var previousServers: ServerManager!
    private var originalImpactFeedback: ImpactFeedbackGeneratorProtocol!
    private var haptics: SpyImpactFeedbackGenerator!
    private var server: Server!
    private var connection: HAMockConnection!
    private var viewModel: WebRTCViewPlayerViewModel!
    private var sessions: [FakeCameraMicrophoneSession] = []

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        originalImpactFeedback = Current.impactFeedback
        haptics = SpyImpactFeedbackGenerator()
        Current.impactFeedback = haptics
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        sessions = []
        viewModel = makeViewModel(supportsTalkback: true)
    }

    override func tearDown() {
        viewModel.stop()
        viewModel = nil
        sessions = []
        Current.cachedApis = [:]
        Current.servers = previousServers
        Current.impactFeedback = originalImpactFeedback
        haptics = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    func testTalkbackSupportComesFromTheHost() {
        XCTAssertTrue(viewModel.isTalkbackSupported)
        XCTAssertFalse(makeViewModel(supportsTalkback: false).isTalkbackSupported)
    }

    func testTalkingOpensAMicrophoneSessionAlongsideTheVideoStream() throws {
        viewModel.start()

        viewModel.toggleTalkback()

        let session = try XCTUnwrap(sessions.first)
        XCTAssertEqual(session.cameraEntityId, "camera.front_door")
        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .connecting)
        XCTAssertEqual(clientConfigRequests.count, 1)

        session.connect(sessionId: "mic-session")

        XCTAssertEqual(viewModel.talkbackState, .talking)
        XCTAssertTrue(viewModel.isTalking)
        XCTAssertEqual(clientConfigRequests.count, 1)
        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid)])
    }

    func testTappingAgainStopsTheMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "mic-session")

        viewModel.toggleTalkback()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
        XCTAssertNil(viewModel.talkbackError)
        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.soft)])
    }

    func testCancellingWhileConnectingIgnoresTheInterruptedStart() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)

        viewModel.toggleTalkback()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
        XCTAssertNil(viewModel.talkbackError)
        XCTAssertTrue(haptics.feedbacks.isEmpty)
    }

    func testAMicrophoneThatCannotStartExplainsWhy() throws {
        viewModel.start()
        viewModel.toggleTalkback()

        try XCTUnwrap(sessions.first).fail(.microphoneDenied)

        XCTAssertEqual(viewModel.talkbackState, .idle)
        XCTAssertEqual(viewModel.talkbackError, L10n.CameraMicrophone.Errors.microphoneDenied)
        XCTAssertEqual(haptics.feedbacks, [.notification(.error)])
    }

    func testTalkingAgainClearsThePreviousError() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        try XCTUnwrap(sessions.first).fail(.timedOut)

        viewModel.toggleTalkback()

        XCTAssertEqual(sessions.count, 2)
        XCTAssertNil(viewModel.talkbackError)
        XCTAssertEqual(viewModel.talkbackState, .connecting)
    }

    func testAMicrophoneSessionThatDropsGoesBackToIdle() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "mic-session")

        session.end(.connectionFailed)

        XCTAssertEqual(viewModel.talkbackState, .idle)
        XCTAssertEqual(viewModel.talkbackError, L10n.CameraMicrophone.Errors.connectionFailed)
        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .notification(.warning)])
    }

    func testTalkingIsIgnoredForACameraThatCannotPlayTheMicrophone() {
        viewModel = makeViewModel(supportsTalkback: false)
        viewModel.start()

        viewModel.toggleTalkback()

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    func testTalkingIsIgnoredWhileThePlayerIsStopped() {
        viewModel.toggleTalkback()

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    func testStoppingThePlayerStopsTheMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "mic-session")

        viewModel.stop()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    /// The player view calls this when the scene goes to the background, so a session the app's
    /// audio background mode would otherwise keep alive stops recording.
    func testStopTalkbackHangsUpALiveMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "mic-session")

        viewModel.stopTalkback()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    /// The microphone permission alert makes the scene inactive, which reaches the view model as
    /// `handleAppBackgrounded`; that must not hang up the session the alert is asking about.
    func testTheAppGoingInactiveKeepsTheMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)

        viewModel.handleAppBackgrounded()

        XCTAssertEqual(session.stopCount, 0)
        XCTAssertEqual(viewModel.talkbackState, .connecting)
    }

    // MARK: - Helpers

    private var clientConfigRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/get_client_config" }
    }

    private func makeViewModel(supportsTalkback: Bool) -> WebRTCViewPlayerViewModel {
        WebRTCViewPlayerViewModel(
            server: server,
            cameraEntityId: "camera.front_door",
            supportsTalkback: supportsTalkback,
            makeClient: { WebRTCFakeStreamClient(configuration: $0) },
            makeMicrophoneSession: { [weak self] server, cameraEntityId in
                let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId)
                self?.sessions.append(session)
                return session
            }
        )
    }
}
