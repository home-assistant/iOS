import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The player asks for a client configuration before it offers anything, and a camera core refuses
/// to serve over WebRTC has to give way to the next streaming method rather than sitting on a
/// spinner.
final class WebRTCViewPlayerViewModelTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var viewModel: WebRTCViewPlayerViewModel!

    /// The message core sends when a camera's `frontend_stream_types` has no WebRTC in it.
    private let unsupportedMessage =
        "Camera does not support WebRTC, frontend_stream_types={<StreamType.HLS: 'hls'>}"

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        // Signaling is only sent over a live socket, so a player under test starts from one.
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        viewModel = WebRTCViewPlayerViewModel(server: server, cameraEntityId: "camera.front_door")
    }

    override func tearDown() {
        viewModel.stop()
        viewModel = nil
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    func testStartAsksForTheClientConfigurationOfTheCamera() throws {
        viewModel.start()

        let request = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(request.request.type.command, "camera/webrtc/get_client_config")
        XCTAssertEqual(request.request.data["entity_id"] as? String, "camera.front_door")
        XCTAssertTrue(viewModel.showLoader)
        XCTAssertFalse(viewModel.didFail)
    }

    /// Core guards the client configuration with the same support check as the offer, so a camera
    /// without WebRTC is known before anything is negotiated — and the player must cascade instead
    /// of sending an offer that is certain to be refused.
    func testACameraWithoutWebRTCSupportFailsWithoutSendingAnOffer() throws {
        viewModel.start()
        let request = try XCTUnwrap(connection.pendingRequests.first)

        request.completion(.failure(.external(.init(
            code: "webrtc_get_client_config_failed",
            message: unsupportedMessage
        ))))
        flushMainQueue()

        XCTAssertTrue(viewModel.isWebRTCUnsupported)
        XCTAssertTrue(viewModel.didFail)
        XCTAssertFalse(viewModel.showLoader)
        XCTAssertFalse(connection.pendingRequests.contains {
            $0.request.type.command == "camera/webrtc/offer"
        })
    }

    /// A configuration that arrives after the player was torn down belongs to a stream nobody is
    /// watching any more; acting on it would resurrect the connection.
    func testAConfigurationArrivingAfterStopIsIgnored() throws {
        viewModel.start()
        let request = try XCTUnwrap(connection.pendingRequests.first)

        viewModel.stop()
        request.completion(.success(.init(value: ["configuration": ["iceServers": []]])))
        flushMainQueue()

        XCTAssertFalse(viewModel.didFail)
        XCTAssertFalse(connection.pendingRequests.contains {
            $0.request.type.command == "camera/webrtc/offer"
        })
    }

    /// Scene changes before anything is playing must not start a stream of their own.
    func testSceneChangesWithoutAStartedStreamDoNothing() {
        viewModel.handleAppBackgrounded()
        viewModel.handleAppForegrounded()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertFalse(viewModel.didFail)
    }

    /// Returning to the foreground while the connection is still being set up leaves the attempt
    /// alone — `.inactive` also covers a passing overlay, and restarting would throw it away.
    func testForegroundingWhileStillConnectingDoesNotRestart() {
        viewModel.start()
        XCTAssertEqual(connection.pendingRequests.count, 1)

        viewModel.handleAppBackgrounded()
        viewModel.handleAppForegrounded()

        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    /// Muting before a stream exists is a no-op rather than a crash: the controls are on screen
    /// while the connection is still being made.
    func testTogglingMuteWithoutAStreamDoesNothing() {
        viewModel.toggleMute()

        XCTAssertTrue(viewModel.isMuted)
    }

    /// The first rendered frame is what takes the loader down.
    func testTheFirstRenderedFrameClearsTheLoader() {
        viewModel.start()
        XCTAssertTrue(viewModel.showLoader)

        viewModel.handleVideoRendered()

        XCTAssertFalse(viewModel.showLoader)
        XCTAssertFalse(viewModel.didFail)
    }

    /// The failure the device logs caught: a network change kills the WebSocket, HAKit takes the
    /// better part of a minute to notice, and a stream set up meanwhile sends signaling that
    /// nothing ever answers. Holding it back is what lets the stream start when the socket returns.
    func testAStreamIsNotSignalledWhileTheServerConnectionIsDown() {
        connection.setState(.connecting, waitForQueue: false)

        viewModel.start()

        XCTAssertTrue(connection.pendingRequests.isEmpty, "Nothing should be sent into a dead socket")
        XCTAssertTrue(viewModel.showLoader)
        XCTAssertFalse(viewModel.didFail)
    }

    /// ...and once it is back, the stream goes out on its own rather than waiting for the user to
    /// reopen the player.
    func testAStreamHeldForTheConnectionIsSentOnceItIsReady() {
        connection.setState(.connecting, waitForQueue: false)
        viewModel.start()
        XCTAssertTrue(connection.pendingRequests.isEmpty)

        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        flushMainQueue()

        XCTAssertEqual(connection.pendingRequests.first?.request.type.command, "camera/webrtc/get_client_config")
        XCTAssertFalse(viewModel.didFail)
    }

    /// A server that refused us is not worth waiting on; the player cascades instead.
    func testARejectedServerConnectionFailsTheStreamRatherThanWaiting() {
        connection.setState(.disconnected(reason: .rejected), waitForQueue: false)

        viewModel.start()

        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(viewModel.didFail)
        XCTAssertFalse(viewModel.showLoader)
    }

    /// Lets the view model's main-queue hop run before the assertions read its state.
    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
    }
}
