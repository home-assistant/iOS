import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The watch streams a recording into a run that starts before the user has finished, so a
/// recording the user drops must abandon that run rather than finish it: finishing would act on
/// whatever was said so far.
final class AssistServiceCancelRunTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var connection: HAMockConnection!
    private var sut: AssistService!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        previousCachedApis = Current.cachedApis
        let servers = FakeServerManager()
        Current.servers = servers
        let server = servers.addFake()

        let api = HomeAssistantAPI(server: server)
        connection = HAMockConnection()
        api.connection = connection
        Current.cachedApis[server.identifier] = api

        sut = AssistService(server: server)
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        sut = nil
        connection = nil
        super.tearDown()
    }

    /// Home Assistant cancels a run whose subscription is dropped, and nothing more is sent to it.
    func testCancelledRunDropsItsSubscriptionAndTakesNoMoreAudio() throws {
        sut.assist(source: .audio(pipelineId: nil, audioSampleRate: 16000, tts: true))
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.initiated(.success(.dictionary([:])))
        subscription.handler(subscription.cancellable, .dictionary([
            "type": "run-start",
            "timestamp": "2026-10-04T10:00:00.000000+00:00",
            "data": ["runner_data": ["stt_binary_handler_id": 1]],
        ]))
        let requestsBeforeCancel = connection.pendingRequests.count

        sut.cancelRun()
        sut.sendAudioData(Data([1, 2]))
        sut.finishSendingAudio()

        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
        XCTAssertEqual(connection.pendingRequests.count, requestsBeforeCancel)
    }

    func testCancellingWithoutARunDoesNothing() {
        sut.cancelRun()

        XCTAssertTrue(connection.cancelledSubscriptions.isEmpty)
    }
}
