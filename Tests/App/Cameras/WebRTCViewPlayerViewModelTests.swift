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

    /// A camera that passes core's support check but has no provider behind it reports it as a
    /// signaling event rather than a rejected request, and it has to cascade the same way.
    func testAnUnsupportedCameraReportedAsASignalingEventCascades() throws {
        let subscription = try startAndOffer()

        subscription.handler(HAMockCancellable {}, .init(value: [
            "type": "error",
            "code": "webrtc_offer_failed",
            "message": unsupportedMessage,
        ]))
        flushMainQueue()

        XCTAssertTrue(viewModel.isWebRTCUnsupported)
        XCTAssertTrue(viewModel.didFail)
        XCTAssertFalse(viewModel.showLoader)
    }

    /// A stream that simply could not be established is a failure, but not a camera the app should
    /// stop offering WebRTC for.
    func testASignalingErrorThatIsNotAboutSupportStillFails() throws {
        let subscription = try startAndOffer()

        subscription.handler(HAMockCancellable {}, .init(value: [
            "type": "error",
            "code": "webrtc_offer_failed",
            "message": "Timeout waiting for the camera",
        ]))
        flushMainQueue()

        XCTAssertTrue(viewModel.didFail)
        XCTAssertFalse(viewModel.isWebRTCUnsupported)
        XCTAssertEqual(viewModel.failureReason, "Timeout waiting for the camera")
    }

    /// The backend's own candidates have to be taken as they come: a real one is added, and the
    /// empty one that marks the end of gathering carries nothing and must not be treated as a
    /// failure. An unknown signal type is likewise ignored rather than tearing the stream down.
    func testRemoteSignalsAreHandledWithoutFailingTheStream() throws {
        let subscription = try startAndOffer()

        subscription.handler(HAMockCancellable {}, .init(value: [
            "type": "session",
            "session_id": "session-1",
        ]))
        subscription.handler(HAMockCancellable {}, .init(value: [
            "type": "candidate",
            "candidate": [
                "candidate": "candidate:1 1 udp 2130706431 192.0.2.1 50000 typ host",
                "sdpMid": "1",
                "sdpMLineIndex": 1,
            ],
        ]))
        subscription.handler(HAMockCancellable {}, .init(value: [
            "type": "candidate",
            "candidate": ["candidate": ""],
        ]))
        subscription.handler(HAMockCancellable {}, .init(value: ["type": "something_new"]))
        flushMainQueue()

        XCTAssertFalse(viewModel.didFail)
        XCTAssertFalse(viewModel.isWebRTCUnsupported)
    }

    /// Starts the stream and answers the client configuration, returning the offer subscription the
    /// backend signals over.
    private func startAndOffer() throws -> HAMockConnection.PendingSubscription {
        viewModel.start()
        let config = try XCTUnwrap(connection.pendingRequests.first)
        config.completion(.success(.init(value: ["configuration": ["iceServers": []]])))
        flushMainQueue()

        for _ in 0 ..< 100 {
            if let subscription = connection.pendingSubscriptions.first(where: {
                $0.request.type.command == "camera/webrtc/offer"
            }) {
                return subscription
            }
            // Pumps the main run loop so the view model's hop onto it — where the offer is sent —
            // gets a chance to run between checks.
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        throw OfferNeverSent()
    }

    private struct OfferNeverSent: Error {}

    /// Lets the view model's main-queue hop run before the assertions read its state.
    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
    }
}
