import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

final class CameraMicrophoneSessionTests: XCTestCase {
    private enum StartOutcome: Equatable {
        case started(sessionId: String)
        case failed(CameraMicrophoneError)
    }

    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var session: CameraMicrophoneSession!
    private var clients: [WebRTCFakeStreamClient] = []
    private var isMicrophoneGranted = true
    private var permissionRequests = 0
    private var startOutcomes: [StartOutcome] = []
    private var endErrors: [CameraMicrophoneError] = []

    private let patientTiming = CameraMicrophoneSession.Timing(connectionTimeout: 30, disconnectedGracePeriod: 30)

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
        isMicrophoneGranted = true
        permissionRequests = 0
        startOutcomes = []
        endErrors = []
        session = makeSession(timing: patientTiming)
    }

    override func tearDown() {
        session?.stop()
        session = nil
        clients = []
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    // MARK: - Starting

    func testADeniedMicrophoneFailsWithoutContactingTheServer() {
        isMicrophoneGranted = false

        start()
        spinMain(until: { !startOutcomes.isEmpty })

        XCTAssertEqual(startOutcomes, [.failed(.microphoneDenied)])
        XCTAssertEqual(permissionRequests, 1)
        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(clients.isEmpty)
    }

    func testTheOfferCarriesTheCameraTheClientSDPAndTheConfiguredICEServers() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        XCTAssertEqual(permissionRequests, 1)
        XCTAssertEqual(clientConfigRequests.first?.request.data["entity_id"] as? String, "camera.front_door")
        XCTAssertEqual(client.configuration.iceServers.count, 1)
        XCTAssertEqual(client.offerCount, 1)
        XCTAssertEqual(offer.request.data["entity_id"] as? String, "camera.front_door")
        XCTAssertEqual(offer.request.data["offer"] as? String, client.offerSDP)
        XCTAssertTrue(startOutcomes.isEmpty)
        XCTAssertFalse(session.isConnected)
    }

    func testAFailedConfigurationFetchStillOffersWithTheFallbackServers() throws {
        start()
        spinMain(until: { !clientConfigRequests.isEmpty })

        try XCTUnwrap(clientConfigRequests.first).completion(.failure(.internal(debugDescription: "boom")))
        flushMainQueue()

        let client = try XCTUnwrap(clients.first)
        XCTAssertEqual(client.configuration.iceServers.count, WebRTCClientConfiguration.fallback.iceServers.count)
        XCTAssertEqual(offerSubscriptions.count, 1)
    }

    func testSignalingWaitsForTheServerConnection() {
        connection.setState(.connecting, waitForQueue: false)

        start()
        spinMain(for: 0.1)
        XCTAssertTrue(clientConfigRequests.isEmpty)

        connection.setState(.ready(version: "1.0-mock"), waitForQueue: false)
        spinMain(until: { !clientConfigRequests.isEmpty })

        XCTAssertEqual(clientConfigRequests.count, 1)
    }

    func testARejectedServerConnectionFailsAsUnavailable() {
        connection.setState(.disconnected(reason: .rejected), waitForQueue: false)

        start()
        spinMain(until: { !startOutcomes.isEmpty })

        XCTAssertEqual(startOutcomes, [.failed(.serverUnavailable)])
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testStartingTwiceRejectsTheSecondStart() {
        start()
        start()

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        spinMain(until: { !clientConfigRequests.isEmpty })
        XCTAssertEqual(permissionRequests, 1)
        XCTAssertEqual(clientConfigRequests.count, 1)
    }

    // MARK: - Connecting

    func testTheStartIsAnsweredWithTheSessionOnceTheConnectionIsUp() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))
        client.changeConnectionState(.checking)
        flushMainQueue()
        XCTAssertTrue(startOutcomes.isEmpty)
        XCTAssertFalse(session.isConnected)

        client.changeConnectionState(.connected)
        flushMainQueue()

        XCTAssertEqual(startOutcomes, [.started(sessionId: "abc")])
        XCTAssertEqual(session.sessionId, "abc")
        XCTAssertTrue(session.isConnected)

        client.changeConnectionState(.completed)
        flushMainQueue()
        XCTAssertEqual(startOutcomes, [.started(sessionId: "abc")])
    }

    func testAConnectionThatComesUpBeforeTheSessionWaitsForIt() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        client.changeConnectionState(.connected)
        flushMainQueue()
        XCTAssertTrue(startOutcomes.isEmpty)
        XCTAssertFalse(session.isConnected)

        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))

        XCTAssertEqual(startOutcomes, [.started(sessionId: "abc")])
        XCTAssertTrue(session.isConnected)
    }

    func testLocalCandidatesWaitForTheSessionAndThenFlush() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        client.discoverLocalCandidate("candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        flushMainQueue()
        XCTAssertTrue(candidateRequests.isEmpty)

        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))

        let flushed = try XCTUnwrap(candidateRequests.first)
        XCTAssertEqual(flushed.request.data["entity_id"] as? String, "camera.front_door")
        XCTAssertEqual(flushed.request.data["session_id"] as? String, "abc")
        let candidate = flushed.request.data["candidate"] as? [String: Any]
        XCTAssertEqual(candidate?["candidate"] as? String, "candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        XCTAssertEqual(candidate?["sdpMid"] as? String, "0")
        XCTAssertEqual(candidate?["sdpMLineIndex"] as? Int32, 0)

        client.discoverLocalCandidate("candidate:2 1 udp 1 10.0.0.3 5001 typ host")
        flushMainQueue()
        XCTAssertEqual(candidateRequests.count, 2)
    }

    func testCandidateDeliveryOutcomesAreAbsorbed() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))
        client.discoverLocalCandidate("candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        client.discoverLocalCandidate("candidate:2 1 udp 1 10.0.0.3 5001 typ host")
        flushMainQueue()

        let requests = candidateRequests
        XCTAssertEqual(requests.count, 2)
        requests[0].completion(.success(.empty))
        requests[1].completion(.failure(.internal(debugDescription: "session gone")))

        XCTAssertTrue(startOutcomes.isEmpty)
        XCTAssertFalse(client.isClosed)
    }

    func testTheAnswerAndRemoteCandidatesAreAppliedToTheClient() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        offer.handler(offer.cancellable, .init(value: ["type": "answer", "answer": "v=0\r\nanswer"]))
        offer.handler(offer.cancellable, .init(value: [
            "type": "candidate",
            "candidate": ["candidate": "candidate:3 1 udp 1 10.0.0.9 6000 typ host", "sdpMLineIndex": 0],
        ]))
        offer.handler(offer.cancellable, .init(value: ["type": "candidate", "candidate": ["candidate": ""]]))

        XCTAssertEqual(client.remoteDescriptions, ["v=0\r\nanswer"])
        XCTAssertEqual(client.remoteCandidates, [
            .init(sdp: "candidate:3 1 udp 1 10.0.0.9 6000 typ host", sdpMid: nil, sdpMLineIndex: 0),
        ])
    }

    func testUnknownAndMalformedSignalsAreIgnored() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        offer.initiated(.success(.empty))
        offer.handler(offer.cancellable, .init(value: ["type": "mystery"]))
        offer.handler(offer.cancellable, .init(value: ["kind": "answer"]))
        offer.handler(offer.cancellable, .init(value: ["type": "session"]))
        offer.handler(offer.cancellable, .init(value: ["type": "answer"]))

        XCTAssertTrue(startOutcomes.isEmpty)
        XCTAssertTrue(client.remoteDescriptions.isEmpty)
        XCTAssertFalse(client.isClosed)
    }

    func testTheMicrophoneIsSwitchedOnTheClient() throws {
        _ = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        session.setMicrophoneEnabled(true)
        XCTAssertTrue(client.isMicrophoneEnabled)

        session.setMicrophoneEnabled(false)
        XCTAssertFalse(client.isMicrophoneEnabled)
    }

    // MARK: - Failures

    func testARejectedOfferFailsTheStartWithCoresMessage() throws {
        let offer = try startAndOffer()

        offer.initiated(.failure(.external(.init(
            code: "webrtc_offer_failed",
            message: "Camera does not support two way audio"
        ))))

        XCTAssertEqual(startOutcomes, [.failed(.signalingFailed("Camera does not support two way audio"))])
        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
        XCTAssertEqual(connection.cancelledSubscriptions.map(\.type.command), ["camera/webrtc/offer"])
    }

    func testAnOfferThatCouldNotBeSentFailsTheStart() throws {
        let offer = try startAndOffer()
        let error = HAError.internal(debugDescription: "socket closed")

        offer.initiated(.failure(error))

        XCTAssertEqual(startOutcomes, [.failed(.signalingFailed(error.localizedDescription))])
    }

    func testASignalingErrorWhileConnectingFailsTheStartWithItsCode() throws {
        let offer = try startAndOffer()

        offer.handler(offer.cancellable, .init(value: ["type": "error", "code": "webrtc_offer_failed"]))

        XCTAssertEqual(startOutcomes, [.failed(.signalingFailed("webrtc_offer_failed"))])
        XCTAssertTrue(endErrors.isEmpty)
    }

    func testASignalingErrorAfterConnectingEndsTheSession() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        connect(offer, client)

        offer.handler(offer.cancellable, .init(value: [
            "type": "error",
            "code": "webrtc_offer_failed",
            "message": "Stream ended",
        ]))

        XCTAssertEqual(endErrors, [.signalingFailed("Stream ended")])
        XCTAssertEqual(session.sessionId, "abc")
        XCTAssertFalse(session.isConnected)
        XCTAssertTrue(client.isClosed)
        XCTAssertEqual(connection.cancelledSubscriptions.map(\.type.command), ["camera/webrtc/offer"])
    }

    func testAFailedConnectionFailsTheStart() throws {
        _ = try startAndOffer()

        try XCTUnwrap(clients.first).changeConnectionState(.failed)
        flushMainQueue()

        XCTAssertEqual(startOutcomes, [.failed(.connectionFailed)])
        XCTAssertTrue(endErrors.isEmpty)
    }

    func testAConnectionThatFailsAfterConnectingEndsTheSession() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        connect(offer, client)

        client.changeConnectionState(.failed)
        flushMainQueue()

        XCTAssertEqual(endErrors, [.connectionFailed])
        XCTAssertTrue(client.isClosed)
    }

    func testAConnectionThatStaysDisconnectedEndsTheSession() throws {
        session = makeSession(timing: .init(connectionTimeout: 30, disconnectedGracePeriod: 0.2))
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        connect(offer, client)

        client.changeConnectionState(.disconnected)
        spinMain(until: { !endErrors.isEmpty })

        XCTAssertEqual(endErrors, [.connectionFailed])
        XCTAssertTrue(client.isClosed)
    }

    func testAConnectionThatRecoversWithinTheGracePeriodKeepsStreaming() throws {
        let timing = CameraMicrophoneSession.Timing(connectionTimeout: 30, disconnectedGracePeriod: 1)
        session = makeSession(timing: timing)
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        connect(offer, client)

        client.changeConnectionState(.disconnected)
        flushMainQueue()
        client.changeConnectionState(.connected)
        spinMain(for: timing.disconnectedGracePeriod * 3)

        XCTAssertTrue(endErrors.isEmpty)
        XCTAssertTrue(session.isConnected)
        XCTAssertFalse(client.isClosed)
    }

    func testNoConnectionBeforeTheTimeoutFailsTheStart() throws {
        session = makeSession(timing: .init(connectionTimeout: 0.2, disconnectedGracePeriod: 30))
        _ = try startAndOffer()

        spinMain(until: { !startOutcomes.isEmpty })

        XCTAssertEqual(startOutcomes, [.failed(.timedOut)])
        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
    }

    func testAConnectedSessionIsNotTimedOut() throws {
        let timing = CameraMicrophoneSession.Timing(connectionTimeout: 1, disconnectedGracePeriod: 30)
        session = makeSession(timing: timing)
        let offer = try startAndOffer()
        try connect(offer, XCTUnwrap(clients.first))

        spinMain(for: timing.connectionTimeout * 3)

        XCTAssertEqual(startOutcomes, [.started(sessionId: "abc")])
        XCTAssertTrue(endErrors.isEmpty)
        XCTAssertTrue(session.isConnected)
    }

    // MARK: - Stopping

    func testStopWhileAskingForTheMicrophoneNeverSignals() {
        start()
        session.stop()
        spinMain(for: 0.1)

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertTrue(connection.pendingRequests.isEmpty)
        XCTAssertTrue(clients.isEmpty)
    }

    func testStopBeforeConnectingAnswersTheStartAsInterrupted() throws {
        _ = try startAndOffer()

        session.stop()

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertTrue(endErrors.isEmpty)
        XCTAssertTrue(try XCTUnwrap(clients.first).isClosed)
        XCTAssertEqual(connection.cancelledSubscriptions.map(\.type.command), ["camera/webrtc/offer"])
    }

    func testStoppingAConnectedSessionDoesNotReportAnEnd() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)
        connect(offer, client)

        session.stop()
        session.stop()

        XCTAssertEqual(startOutcomes, [.started(sessionId: "abc")])
        XCTAssertTrue(endErrors.isEmpty)
        XCTAssertFalse(session.isConnected)
        XCTAssertTrue(client.isClosed)
    }

    func testEventsAfterStopAreIgnored() throws {
        let offer = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        session.stop()
        client.changeConnectionState(.connected)
        client.discoverLocalCandidate("candidate:1 1 udp 1 10.0.0.2 5000 typ host")
        flushMainQueue()
        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))

        XCTAssertEqual(startOutcomes, [.failed(.interrupted)])
        XCTAssertFalse(session.isConnected)
        XCTAssertTrue(candidateRequests.isEmpty)
    }

    func testReleasingTheSessionClosesTheClient() throws {
        _ = try startAndOffer()
        let client = try XCTUnwrap(clients.first)

        session = nil

        XCTAssertTrue(client.isClosed)
    }

    // MARK: - Helpers

    private var clientConfigRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/get_client_config" }
    }

    private var candidateRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/candidate" }
    }

    private var offerSubscriptions: [HAMockConnection.PendingSubscription] {
        connection.pendingSubscriptions.filter { $0.request.type.command == "camera/webrtc/offer" }
    }

    private func makeSession(timing: CameraMicrophoneSession.Timing) -> CameraMicrophoneSession {
        let session = CameraMicrophoneSession(
            server: server,
            cameraEntityId: "camera.front_door",
            makeClient: { [weak self] configuration in
                let client = WebRTCFakeStreamClient(configuration: configuration)
                self?.clients.append(client)
                return client
            },
            requestMicrophonePermission: { [weak self] in
                self?.permissionRequests += 1
                return self?.isMicrophoneGranted ?? false
            },
            timing: timing
        )
        session.onEnd = { [weak self] error in
            self?.endErrors.append(error)
        }
        return session
    }

    private func start() {
        session.start { [weak self] result in
            switch result {
            case let .success(sessionId):
                self?.startOutcomes.append(.started(sessionId: sessionId))
            case let .failure(error):
                self?.startOutcomes.append(.failed(error))
            }
        }
    }

    private func connect(_ offer: HAMockConnection.PendingSubscription, _ client: WebRTCFakeStreamClient) {
        offer.handler(offer.cancellable, .init(value: ["type": "session", "session_id": "abc"]))
        client.changeConnectionState(.connected)
        flushMainQueue()
    }

    private func startAndOffer() throws -> HAMockConnection.PendingSubscription {
        start()
        spinMain(until: { !clientConfigRequests.isEmpty })
        try XCTUnwrap(clientConfigRequests.first).completion(.success(.init(value: clientConfiguration)))
        flushMainQueue()
        return try XCTUnwrap(offerSubscriptions.first)
    }

    private func flushMainQueue() {
        let flushed = expectation(description: "main queue flushed")
        DispatchQueue.main.async { flushed.fulfill() }
        wait(for: [flushed], timeout: 30.0)
    }

    private func spinMain(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
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
