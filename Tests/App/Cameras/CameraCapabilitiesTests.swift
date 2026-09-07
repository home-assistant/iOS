import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// `camera/capabilities` is what tells the player which stream types a camera actually has, so the
/// decoding has to survive whatever the server reports and the fetch has to fail softly.
final class CameraCapabilitiesTests: XCTestCase {
    private var previousServers: ServerManager!
    private var server: Server!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

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
    }

    override func tearDown() {
        Current.cachedApis = [:]
        Current.servers = previousServers
        api = nil
        connection = nil
        server = nil
        super.tearDown()
    }

    func testDecodesEveryStreamTypeTheServerReports() {
        let capabilities = CameraCapabilities(data: .init(value: ["frontend_stream_types": ["hls", "web_rtc"]]))
        XCTAssertEqual(capabilities.frontendStreamTypes, [.hls, .webRTC])
    }

    func testDecodesACameraWithoutStreamSupportAsEmpty() {
        let capabilities = CameraCapabilities(data: .init(value: ["frontend_stream_types": [String]()]))
        XCTAssertTrue(capabilities.frontendStreamTypes.isEmpty)
    }

    /// A stream type a future core adds must not take the ones this app does understand with it.
    func testDropsUnknownStreamTypesInsteadOfDiscardingTheRest() {
        let capabilities = CameraCapabilities(data: .init(value: ["frontend_stream_types": ["hls", "holodeck"]]))
        XCTAssertEqual(capabilities.frontendStreamTypes, [.hls])
    }

    func testDecodesAResponseWithoutTheKeyAsEmpty() {
        let capabilities = CameraCapabilities(data: .init(value: [String: Any]()))
        XCTAssertTrue(capabilities.frontendStreamTypes.isEmpty)
    }

    func testFetchAsksTheServerAboutTheCameraAndReturnsWhatItSays() async throws {
        let task = Task { [server] in
            await CameraCapabilities.fetch(server: server!, cameraEntityId: "camera.front_door")
        }

        let request = try await capabilitiesRequest()
        XCTAssertEqual(request.request.data["entity_id"] as? String, "camera.front_door")
        request.completion(.success(.init(value: ["frontend_stream_types": ["web_rtc"]])))

        let capabilities = await task.value
        XCTAssertEqual(capabilities?.frontendStreamTypes, [.webRTC])
    }

    /// A server that can't answer — an older core without the command, or a connection that dropped
    /// — leaves the plan undecided rather than claiming the camera supports nothing, which would
    /// send every camera straight to the still-image proxy.
    func testFetchReturnsNilWhenTheRequestFails() async throws {
        let task = Task { [server] in
            await CameraCapabilities.fetch(server: server!, cameraEntityId: "camera.front_door")
        }

        let request = try await capabilitiesRequest()
        request.completion(.failure(.internal(debugDescription: "unknown command")))

        let capabilities = await task.value
        XCTAssertNil(capabilities)
    }

    /// The fetch runs off this test's own execution context, so wait for the request to reach the
    /// mock connection rather than assuming it has been sent by the time the test looks.
    private func capabilitiesRequest() async throws -> HAMockConnection.PendingRequest {
        for _ in 0 ..< 200 {
            if let pending = connection.pendingRequests.first(where: {
                $0.request.type.command == CameraCapabilities.webSocketCommand
            }) {
                return pending
            }
            try await Task.sleep(nanoseconds: 10 * NSEC_PER_MSEC)
        }
        throw CapabilitiesRequestNeverSent()
    }

    private struct CapabilitiesRequestNeverSent: Error {}
}
