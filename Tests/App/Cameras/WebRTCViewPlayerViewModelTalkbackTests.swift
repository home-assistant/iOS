import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

final class WebRTCViewPlayerViewModelTalkbackTests: XCTestCase {
    private struct MadeClient {
        let client: WebRTCFakeStreamClient
        let supportsTalkback: Bool
    }

    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var viewModel: WebRTCViewPlayerViewModel!
    private var madeClients: [MadeClient] = []
    private var isMicrophoneGranted = true

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
        madeClients = []
        isMicrophoneGranted = true
        makeViewModel()
    }

    override func tearDown() {
        viewModel.stop()
        viewModel = nil
        madeClients = []
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    // MARK: - Choosing the client

    func testACameraWithTwoWayAudioConnectsWithTheMicrophoneArmedButSilent() throws {
        viewModel.start()
        XCTAssertTrue(clientConfigRequests.isEmpty)

        try deliverCamera(supportedFeatures: 6)
        spinMain(until: { !clientConfigRequests.isEmpty })
        try answerClientConfig(at: 0)

        XCTAssertTrue(viewModel.isTalkbackSupported)
        let made = try XCTUnwrap(madeClients.first)
        XCTAssertTrue(made.supportsTalkback)
        XCTAssertFalse(made.client.isMicrophoneEnabled)
        XCTAssertFalse(viewModel.isTalking)
    }

    func testACameraWithoutTwoWayAudioConnectsWithoutTheMicrophone() throws {
        viewModel.start()

        try deliverCamera(supportedFeatures: 2)
        spinMain(until: { !clientConfigRequests.isEmpty })
        try answerClientConfig(at: 0)

        XCTAssertFalse(viewModel.isTalkbackSupported)
        XCTAssertEqual(madeClients.map(\.supportsTalkback), [false])
    }

    func testACameraThatNeverShowsUpConnectsWithoutTheMicrophone() throws {
        makeViewModel(talkbackSupportTimeout: 0.2)

        viewModel.start()
        spinMain(until: { !clientConfigRequests.isEmpty })
        try answerClientConfig(at: 0)

        XCTAssertFalse(viewModel.isTalkbackSupported)
        XCTAssertEqual(madeClients.map(\.supportsTalkback), [false])
    }

    func testAPlayerWithoutTalkbackNeverLooksTheCameraUp() throws {
        makeViewModel(supportsTalkback: false)

        viewModel.start()

        XCTAssertFalse(connection.pendingSubscriptions.contains { $0.request.type.command == "subscribe_entities" })
        XCTAssertEqual(clientConfigRequests.count, 1)
        try answerClientConfig(at: 0)
        XCTAssertEqual(madeClients.map(\.supportsTalkback), [false])
    }

    func testALookupThatAnswersAfterStopDoesNotConnect() throws {
        viewModel.start()
        viewModel.stop()

        try deliverCamera(supportedFeatures: 6)
        spinMain(for: 0.2)

        XCTAssertTrue(clientConfigRequests.isEmpty)
        XCTAssertFalse(viewModel.isTalkbackSupported)
    }

    // MARK: - Talking

    func testTalkingTurnsTheMicrophoneOnAndOff() throws {
        let client = try startTalkbackCapableStream()

        viewModel.toggleTalkback()
        spinMain(until: { viewModel.isTalking })
        XCTAssertTrue(client.isMicrophoneEnabled)

        viewModel.toggleTalkback()
        XCTAssertFalse(viewModel.isTalking)
        XCTAssertFalse(client.isMicrophoneEnabled)
    }

    func testADeniedMicrophoneKeepsTheMicrophoneOff() throws {
        isMicrophoneGranted = false
        let client = try startTalkbackCapableStream()

        viewModel.toggleTalkback()
        spinMain(until: { viewModel.failureReason != nil })

        XCTAssertEqual(viewModel.failureReason, L10n.CameraPlayer.Talkback.microphoneDenied)
        XCTAssertFalse(viewModel.isTalking)
        XCTAssertFalse(client.isMicrophoneEnabled)
    }

    func testARebuiltConnectionKeepsTalking() throws {
        let first = try startTalkbackCapableStream()
        viewModel.toggleTalkback()
        spinMain(until: { viewModel.isTalking })

        first.changeConnectionState(.failed)
        flushMainQueue()
        try answerClientConfig(at: 1)

        let rebuilt = try XCTUnwrap(madeClients.last)
        XCTAssertEqual(madeClients.count, 2)
        XCTAssertTrue(rebuilt.supportsTalkback)
        XCTAssertTrue(rebuilt.client.isMicrophoneEnabled)
    }

    func testStoppingThePlayerStopsTalking() throws {
        _ = try startTalkbackCapableStream()
        viewModel.toggleTalkback()
        spinMain(until: { viewModel.isTalking })

        viewModel.stop()

        XCTAssertFalse(viewModel.isTalking)
    }

    // MARK: - Helpers

    private var clientConfigRequests: [HAMockConnection.PendingRequest] {
        connection.pendingRequests.filter { $0.request.type.command == "camera/webrtc/get_client_config" }
    }

    private func makeViewModel(supportsTalkback: Bool = true, talkbackSupportTimeout: TimeInterval = 30) {
        viewModel?.stop()
        viewModel = WebRTCViewPlayerViewModel(
            server: server,
            cameraEntityId: "camera.front_door",
            supportsTalkback: supportsTalkback,
            makeClient: { [weak self] configuration, withTalkback in
                let client = WebRTCFakeStreamClient(configuration: configuration)
                self?.madeClients.append(.init(client: client, supportsTalkback: withTalkback))
                return client
            },
            requestMicrophonePermission: { [weak self] in
                self?.isMicrophoneGranted ?? false
            },
            timing: .init(
                connectionTimeout: 30,
                disconnectedGracePeriod: 30,
                signalingStallTimeout: 30,
                connectionWaitTimeout: 30,
                backgroundTeardownDelay: 60,
                talkbackSupportTimeout: talkbackSupportTimeout
            )
        )
    }

    private func deliverCamera(supportedFeatures: Int) throws {
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.first {
            $0.request.type.command == "subscribe_entities"
        })
        subscription.handler(subscription.cancellable, .init(value: [
            "a": [
                "camera.front_door": ["s": "idle", "a": ["supported_features": supportedFeatures]],
            ],
        ]))
    }

    private func startTalkbackCapableStream() throws -> WebRTCFakeStreamClient {
        viewModel.start()
        try deliverCamera(supportedFeatures: 6)
        spinMain(until: { !clientConfigRequests.isEmpty })
        try answerClientConfig(at: 0)
        return try XCTUnwrap(madeClients.first).client
    }

    private func answerClientConfig(at index: Int) throws {
        let requests = clientConfigRequests
        let request = try XCTUnwrap(requests.indices.contains(index) ? requests[index] : nil)
        request.completion(.success(.init(value: ["configuration": ["iceServers": []]])))
        flushMainQueue()
        flushMainQueue()
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
