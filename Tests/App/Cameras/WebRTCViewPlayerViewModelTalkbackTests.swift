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

    /// Stopping mutes the microphone and keeps its connection, so talking again does not have to
    /// connect it from scratch.
    func testTappingAgainMutesAndHoldsTheMicrophone() throws {
        let session = try startTalking()

        viewModel.toggleTalkback()

        XCTAssertEqual(session.stopCount, 0)
        XCTAssertFalse(session.isMicrophoneEnabled)
        XCTAssertEqual(viewModel.talkbackState, .idle)
        XCTAssertNil(viewModel.talkbackError)
        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.soft)])
    }

    func testTalkingAgainWhileHeldPicksUpTheSameMicrophoneAtOnce() throws {
        let session = try startTalking()
        viewModel.toggleTalkback()

        viewModel.toggleTalkback()

        XCTAssertEqual(sessions.count, 1)
        XCTAssertTrue(session.isMicrophoneEnabled)
        XCTAssertEqual(viewModel.talkbackState, .talking)
        XCTAssertEqual(haptics.feedbacks, [.impact(.rigid), .impact(.soft), .impact(.rigid)])
    }

    func testAHeldMicrophoneIsHungUpOnceTheHoldRunsOut() throws {
        viewModel = makeViewModel(supportsTalkback: true, microphoneHoldDuration: 0.05)
        let session = try startTalking()

        viewModel.toggleTalkback()
        spinMain(until: { session.stopCount == 1 })

        viewModel.toggleTalkback()
        XCTAssertEqual(sessions.count, 2, "Talking after the hold connects a new microphone")
    }

    func testAHeldMicrophoneThatDropsIsForgottenQuietly() throws {
        let session = try startTalking()
        viewModel.toggleTalkback()

        session.end(.connectionFailed)
        viewModel.toggleTalkback()

        XCTAssertNil(viewModel.talkbackError)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(viewModel.talkbackState, .connecting)
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
        let session = try startTalking()

        viewModel.stop()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    func testStoppingThePlayerHangsUpAHeldMicrophone() throws {
        let session = try startTalking()
        viewModel.toggleTalkback()

        viewModel.stop()

        XCTAssertEqual(session.stopCount, 1)
    }

    /// The app keeps the audio background mode, so a session left running once the scene is in the
    /// background would go on recording.
    func testTheSceneGoingToTheBackgroundHangsUpTheMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)
        session.connect(sessionId: "mic-session")

        viewModel.handleScenePhase(.background)

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.talkbackState, .idle)
    }

    func testTheSceneGoingToTheBackgroundHangsUpAHeldMicrophone() throws {
        let session = try startTalking()
        viewModel.toggleTalkback()

        viewModel.handleScenePhase(.background)

        XCTAssertEqual(session.stopCount, 1)
    }

    /// The microphone permission alert makes the scene inactive; that must not hang up the session the
    /// alert is asking about.
    func testTheSceneGoingInactiveKeepsTheMicrophone() throws {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.first)

        viewModel.handleScenePhase(.inactive)
        viewModel.handleScenePhase(.active)

        XCTAssertEqual(session.stopCount, 0)
        XCTAssertEqual(viewModel.talkbackState, .connecting)
    }

    // MARK: - Helpers

    private var clientConfigRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/get_client_config" }
    }

    private func makeViewModel(
        supportsTalkback: Bool,
        microphoneHoldDuration: TimeInterval = 60
    ) -> WebRTCViewPlayerViewModel {
        var timing = WebRTCViewPlayerViewModel.Timing.production
        timing.microphoneHoldDuration = microphoneHoldDuration
        return WebRTCViewPlayerViewModel(
            server: server,
            cameraEntityId: "camera.front_door",
            supportsTalkback: supportsTalkback,
            makeClient: { WebRTCFakeStreamClient(configuration: $0) },
            makeMicrophoneSession: { [weak self] server, cameraEntityId in
                let session = FakeCameraMicrophoneSession(server: server, cameraEntityId: cameraEntityId)
                self?.sessions.append(session)
                return session
            },
            timing: timing
        )
    }

    private func startTalking() throws -> FakeCameraMicrophoneSession {
        viewModel.start()
        viewModel.toggleTalkback()
        let session = try XCTUnwrap(sessions.last)
        session.connect(sessionId: "mic-session")
        XCTAssertEqual(viewModel.talkbackState, .talking)
        return session
    }

    private func spinMain(
        until condition: () -> Bool,
        timeout: TimeInterval = 30,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(condition(), "Timed out spinning the main run loop", file: file, line: line)
    }
}
