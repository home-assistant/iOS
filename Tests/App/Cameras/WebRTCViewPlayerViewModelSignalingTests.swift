import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Drives the view model through the whole signaling exchange with a fake peer connection client,
/// which is what lets the paths after the client configuration be exercised without opening the
/// sockets a real `RTCPeerConnection` would.
final class WebRTCViewPlayerViewModelSignalingTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var viewModel: WebRTCViewPlayerViewModel!
    private var clients: [WebRTCFakeStreamClient] = []

    private let timing = WebRTCViewPlayerViewModel.Timing(
        connectionTimeout: 0.2,
        disconnectedGracePeriod: 0.1,
        signalingStallTimeout: 0.2,
        connectionWaitTimeout: 1.0,
        backgroundTeardownDelay: 60
    )

    private let unsupportedMessage =
        "Camera does not support WebRTC, frontend_stream_types={<StreamType.HLS: 'hls'>}"

    private let clientConfiguration: [String: Any] = [
        "configuration": [
            "iceServers": [
                ["urls": ["turn:turn.example.com:3478"], "username": "user", "credential": "secret"],
            ],
        ],
    ]

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()
        api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        api.connection = connection
        Current.cachedApis[server.identifier] = api
        clients = []
        viewModel = WebRTCViewPlayerViewModel(
            server: server,
            cameraEntityId: "camera.front_door",
            makeClient: { [weak self] configuration in
                let client = WebRTCFakeStreamClient(configuration: configuration)
                self?.clients.append(client)
                return client
            },
            timing: timing
        )
    }

    override func tearDown() {
        viewModel.stop()
        viewModel = nil
        clients = []
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    // MARK: - Offer

    func testTheOfferCarriesTheClientSDPAndTheConfiguredICEServers() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        XCTAssertEqual(client.configuration.iceServers.count, 1)
        XCTAssertEqual(offer.request.type.command, "camera/webrtc/offer")
        XCTAssertEqual(offer.request.data["entity_id"] as? String, "camera.front_door")
        XCTAssertEqual(offer.request.data["offer"] as? String, client.offerSDP)
        XCTAssertFalse(viewModel.didFail)
    }

    func testAFailedConfigurationFetchStillOffersWithTheFallbackServers() throws {
        viewModel.start()
        try clientConfigRequest(at: 0).completion(.failure(.internal(debugDescription: "boom")))
        flushMainQueue()
        flushMainQueue()

        let client = try XCTUnwrap(clients.first)
        XCTAssertEqual(client.configuration.iceServers.count, WebRTCClientConfiguration.fallback.iceServers.count)
        XCTAssertEqual(connection.pendingSubscriptions.count, 1)
    }

    func testARejectedOfferFromAnUnsupportedCameraFailsTheStream() throws {
        let offer = try startAndOffer()

        offer.initiated(.failure(.external(.init(code: "webrtc_offer_failed", message: unsupportedMessage))))
        flushMainQueue()

        XCTAssertTrue(viewModel.isWebRTCUnsupported)
        XCTAssertTrue(viewModel.didFail)
        XCTAssertEqual(viewModel.failureReason, unsupportedMessage)
    }

    // MARK: - Session, answer and candidates

    func testLocalCandidatesWaitForTheSessionAndThenFlush() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        client.discoverLocalCandidate("candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        flushMainQueue()
        XCTAssertTrue(candidateRequests.isEmpty, "A candidate has nowhere to go before the session exists")

        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))
        flushMainQueue()

        let flushed = try XCTUnwrap(candidateRequests.first)
        XCTAssertEqual(flushed.request.data["session_id"] as? String, "abc")
        let candidate = flushed.request.data["candidate"] as? [String: Any]
        XCTAssertEqual(candidate?["candidate"] as? String, "candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        XCTAssertEqual(candidate?["sdpMid"] as? String, "0")

        client.discoverLocalCandidate("candidate:2 1 udp 1 10.0.0.3 5001 typ host")
        flushMainQueue()
        XCTAssertEqual(candidateRequests.count, 2)
    }

    func testTheAnswerIsAppliedToTheClient() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        offer.handler(offer.cancellable, .init(value: ["type": "answer", "answer": "v=0\r\nanswer"]))
        flushMainQueue()

        XCTAssertEqual(client.remoteDescriptions, ["v=0\r\nanswer"])
    }

    func testRemoteCandidatesAreAppliedWithTheFrontendsMidFallback() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        offer.handler(offer.cancellable, .init(value: [
            "type": "candidate",
            "candidate": ["candidate": "candidate:9 1 udp 1 192.168.1.5 6000 typ host"],
        ]))
        offer.handler(offer.cancellable, .init(value: [
            "type": "candidate",
            "candidate": ["candidate": "candidate:10 1 udp 1 192.168.1.6 6001 typ host", "sdpMLineIndex": 1],
        ]))
        offer.handler(offer.cancellable, .init(value: [
            "type": "candidate",
            "candidate": ["candidate": ""],
        ]))
        flushMainQueue()

        XCTAssertEqual(client.remoteCandidates, [
            .init(sdp: "candidate:9 1 udp 1 192.168.1.5 6000 typ host", sdpMid: "0", sdpMLineIndex: 0),
            .init(sdp: "candidate:10 1 udp 1 192.168.1.6 6001 typ host", sdpMid: nil, sdpMLineIndex: 1),
        ])
    }

    func testASignalingErrorFailsTheStreamAndRecognisesAnUnsupportedCamera() throws {
        let offer = try startAndOffer()

        offer.handler(offer.cancellable, .init(value: [
            "type": "error",
            "code": "webrtc_offer_failed",
            "message": "Camera does not support WebRTC",
        ]))
        flushMainQueue()

        XCTAssertTrue(viewModel.isWebRTCUnsupported)
        XCTAssertTrue(viewModel.didFail)
        XCTAssertEqual(viewModel.failureReason, "Camera does not support WebRTC")
        XCTAssertFalse(viewModel.showLoader)
    }

    func testAnUnknownSignalIsIgnored() throws {
        let offer = try startAndOffer()

        offer.handler(offer.cancellable, .init(value: ["type": "something_new"]))
        flushMainQueue()

        XCTAssertFalse(viewModel.didFail)
    }

    // MARK: - Connection state

    func testAFailedConnectionIsRebuiltBeforeGivingUp() throws {
        _ = try startAndOffer()

        try XCTUnwrap(clients.first).changeConnectionState(.failed)
        flushMainQueue()
        XCTAssertEqual(clientConfigRequests.count, 2, "The first failure rebuilds the stream")
        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
        XCTAssertFalse(viewModel.didFail)

        try answerClientConfig(at: 1)
        try XCTUnwrap(clients.last).changeConnectionState(.failed)
        flushMainQueue()
        XCTAssertEqual(clientConfigRequests.count, 3, "The second failure rebuilds it once more")

        try answerClientConfig(at: 2)
        try XCTUnwrap(clients.last).changeConnectionState(.failed)
        flushMainQueue()
        XCTAssertEqual(clientConfigRequests.count, 3)
        XCTAssertTrue(viewModel.didFail)
    }

    func testAConnectionThatRecoversWithinTheGracePeriodIsNotRebuilt() throws {
        _ = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        viewModel.handleVideoRendered()
        client.changeConnectionState(.disconnected)
        flushMainQueue()
        client.changeConnectionState(.connected)
        spinMain(for: timing.disconnectedGracePeriod * 3)

        XCTAssertEqual(clientConfigRequests.count, 1)
        XCTAssertFalse(client.isClosed)
    }

    func testAConnectionThatStaysDisconnectedIsRebuilt() throws {
        _ = try startAndOffer()

        try XCTUnwrap(clients.first).changeConnectionState(.disconnected)
        spinMain(for: timing.disconnectedGracePeriod * 3)

        XCTAssertEqual(clientConfigRequests.count, 2)
        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
    }

    func testStateChangesFromAReplacedClientAreIgnored() throws {
        _ = try startAndOffer()
        let replaced = try XCTUnwrap(clients.first)
        replaced.changeConnectionState(.failed)
        flushMainQueue()
        try answerClientConfig(at: 1)

        replaced.changeConnectionState(.failed)
        flushMainQueue()

        XCTAssertEqual(clientConfigRequests.count, 2)
        XCTAssertFalse(viewModel.didFail)
    }

    // MARK: - Timeouts

    func testNoFrameBeforeTheTimeoutFailsTheStream() throws {
        _ = try startAndOffer()

        spinMain(for: timing.connectionTimeout * 3)

        XCTAssertTrue(viewModel.didFail)
        XCTAssertFalse(viewModel.showLoader)
    }

    func testARenderedFrameCancelsTheTimeout() throws {
        _ = try startAndOffer()

        viewModel.handleVideoRendered()
        spinMain(for: timing.connectionTimeout * 3)

        XCTAssertFalse(viewModel.didFail)
    }

    func testAServerConnectionThatNeverComesBackFailsTheStream() {
        connection.setState(.connecting, waitForQueue: false)
        viewModel.start()

        spinMain(for: timing.connectionWaitTimeout * 1.5)

        XCTAssertTrue(viewModel.didFail)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testUnansweredSignalingWaitsForAFreshConnectionAndRetries() {
        viewModel.start()
        XCTAssertEqual(clientConfigRequests.count, 1)

        spinMain(for: timing.signalingStallTimeout * 2)
        XCTAssertEqual(clientConfigRequests.count, 1, "A stale ready state is not trusted twice")
        XCTAssertFalse(viewModel.didFail)

        connection.setState(.connecting, waitForQueue: false)
        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        flushMainQueue()

        XCTAssertEqual(clientConfigRequests.count, 2)
    }

    // MARK: - Lifecycle

    func testForegroundingRestartsAStreamWhoseConnectionDied() throws {
        _ = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        viewModel.handleAppBackgrounded()
        viewModel.handleAppForegrounded()
        XCTAssertEqual(clientConfigRequests.count, 1, "A live connection survives a trip to the background")

        client.isConnectionAlive = false
        viewModel.handleAppBackgrounded()
        viewModel.handleAppForegrounded()

        XCTAssertEqual(clientConfigRequests.count, 2)
        XCTAssertTrue(client.isClosed)
    }

    func testMuteTogglesTheClientAudio() throws {
        _ = try startAndOffer()

        viewModel.toggleMute()
        XCTAssertFalse(viewModel.isMuted)

        viewModel.toggleMute()
        XCTAssertTrue(viewModel.isMuted)
    }

    func testStopClosesTheClientAndCancelsTheOffer() throws {
        _ = try startAndOffer()

        viewModel.stop()

        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
    }

    // MARK: - Helpers

    private var clientConfigRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/get_client_config" }
    }

    private var candidateRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/candidate" }
    }

    private func clientConfigRequest(at index: Int) throws -> HAMockConnection.PendingRequest {
        let requests = clientConfigRequests
        return try XCTUnwrap(requests.indices.contains(index) ? requests[index] : nil)
    }

    /// The configuration lands on the main queue, and the offer the client produces hops there once
    /// more before it is sent, so both hops are drained before anything is asserted.
    private func answerClientConfig(at index: Int) throws {
        try clientConfigRequest(at: index).completion(.success(.init(value: clientConfiguration)))
        flushMainQueue()
        flushMainQueue()
    }

    private func startAndOffer() throws -> HAMockConnection.PendingSubscription {
        viewModel.start()
        try answerClientConfig(at: 0)
        return try XCTUnwrap(connection.pendingSubscriptions.first)
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 2)
    }

    private func spinMain(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
}
