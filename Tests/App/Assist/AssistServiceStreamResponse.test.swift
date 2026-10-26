import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// A streamed reply can hold several assistant messages, for example a sentence before a tool call
/// and the answer after it. The chat log marks each one with a `role`, which the delegate needs to
/// keep the messages apart.
final class AssistServiceStreamResponseTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!
    private var connection: HAMockConnection!
    private var delegate: SpyAssistServiceDelegate!
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

        delegate = SpyAssistServiceDelegate()
        sut = AssistService(server: server)
        sut.delegate = delegate
    }

    override func tearDown() {
        Current.cachedApis = previousCachedApis
        Current.servers = previousServers
        sut = nil
        delegate = nil
        connection = nil
        super.tearDown()
    }

    func testAssistantRoleStartsANewStreamedMessage() throws {
        sut.assist(source: .text(input: "What is the weather?", pipelineId: nil, expectTTS: false))
        let subscription = try XCTUnwrap(connection.pendingSubscriptions.last)
        subscription.initiated(.success(.dictionary([:])))

        for delta: [String: Any] in [
            ["role": "assistant", "content": "Let me check."],
            ["role": "tool_result", "tool_call_id": "call-1"],
            ["role": "assistant"],
            ["content": "It is sunny."],
        ] {
            subscription.handler(subscription.cancellable, .dictionary([
                "type": "intent-progress",
                "timestamp": "2026-10-23T10:00:00.000000+00:00",
                "data": ["chat_log_delta": delta],
            ]))
        }

        XCTAssertEqual(delegate.calls, ["start", "Let me check.", "", "start", "", "It is sunny."])
    }

    func testChatLogDeltaRoleRawValues() {
        typealias Role = AssistResponse.AssistData.ChatLogDelta.Role
        XCTAssertEqual(Role.assistant.rawValue, "assistant")
        XCTAssertEqual(Role.toolResult.rawValue, "tool_result")
        XCTAssertEqual(Role.unknown.rawValue, "unknown")
    }

    func testChatLogDeltaDecodesUnexpectedRoleAsUnknown() throws {
        typealias Delta = AssistResponse.AssistData.ChatLogDelta
        let unexpected = try Delta(data: .dictionary(["role": "system", "content": "Hi"]))
        XCTAssertEqual(unexpected.role, .unknown)
        XCTAssertEqual(unexpected.content, "Hi")
        XCTAssertNil(try Delta(data: .dictionary(["content": "there"])).role)
    }

    private final class SpyAssistServiceDelegate: AssistServiceDelegate {
        private(set) var calls: [String] = []

        func didReceiveEvent(_ event: AssistEvent) {}
        func didReceiveSttContent(_ content: String) {}
        func didReceiveIntentEndContent(_ content: String) {}
        func didReceiveGreenLightForAudioInput() {}
        func didReceiveTtsMediaUrl(_ mediaUrl: URL) {}
        func didReceiveError(code: String, message: String) {}

        func didStartStreamResponseMessage() {
            calls.append("start")
        }

        func didReceiveStreamResponseChunk(_ content: String) {
            calls.append(content)
        }
    }
}
