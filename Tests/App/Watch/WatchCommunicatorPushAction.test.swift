@testable import HomeAssistant
import ObjectMapper
import PromiseKit
@testable import Shared
import UserNotifications
import XCTest

/// The reply the iPhone owes the watch for a notification action. The watch shows the user whether
/// their reply went through and waits on this answer, so every path has to produce one.
final class WatchCommunicatorPushActionTests: XCTestCase {
    private var service: WatchCommunicatorService!
    private var server: Server!
    private var api: FakePushActionAPI!
    private var previousServers: ServerManager!
    private var previousCachedApis: [Identifier<Server>: HomeAssistantAPI]!

    override func setUpWithError() throws {
        try super.setUpWithError()

        previousServers = Current.servers
        previousCachedApis = Current.cachedApis

        let servers = FakeServerManager()
        Current.servers = servers
        server = servers.addFake()

        api = FakePushActionAPI(server: server)
        Current.setCachedApi(api, for: server.identifier)

        service = WatchCommunicatorService()
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.cachedApis = previousCachedApis

        super.tearDown()
    }

    private func info(textInput: String? = nil) -> HomeAssistantAPI.PushActionInfo {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "DYNAMIC"
        return .init(content: content, actionIdentifier: "REPLY", textInput: textInput)
    }

    private func message(
        _ content: [String: Any],
        reply: @escaping (HAWatchConnectivity.ImmediateMessage) -> Void
    ) -> HAWatchConnectivity.InteractiveImmediateMessage {
        .init(
            identifier: InteractiveImmediateMessages.pushAction.rawValue,
            content: content,
            reply: reply
        )
    }

    /// The handler rejects an unusable message before it reaches the API, so its reply lands while
    /// `pushAction` is still on the stack — no waiting involved.
    private func rejectedReply(to content: [String: Any]) -> [String: Any] {
        var received: [String: Any]?
        service.pushAction(message: message(content, reply: { received = $0.content }))

        XCTAssertNotNil(received, "the handler has to answer every message")
        XCTAssertNil(api.receivedInfo)
        return received ?? [:]
    }

    /// Runs a message the handler does forward, and waits for the answer the API's result produces.
    private func forwardedReply(to content: [String: Any]) -> [String: Any] {
        let replied = expectation(description: "replied")
        var received: [String: Any] = [:]

        let outgoing = message(content, reply: { answer in
            received = answer.content
            replied.fulfill()
        })
        service.pushAction(message: outgoing)

        wait(for: [replied], timeout: 5)
        return received
    }

    private func forwardableContent(textInput: String) -> [String: Any] {
        [
            "PushActionInfo": info(textInput: textInput).toJSON(),
            "Server": server.identifier.rawValue,
        ]
    }

    /// Covers both halves of the payload guard, which share one branch. The unmappable-payload half
    /// is deliberately not exercised separately: ObjectMapper records a test issue of its own
    /// ("Got an error while mapping.") whenever an immutable map fails, which fails the test.
    func testRepliesFailureWhenThePayloadIsMissing() {
        let received = rejectedReply(to: [:])

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
    }

    func testRepliesFailureWhenTheServerIsUnknown() {
        let content: [String: Any] = [
            "PushActionInfo": info().toJSON(),
            "Server": "not-a-configured-server",
        ]

        let received = rejectedReply(to: content)

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
    }

    func testRepliesFailureWhenTheServerIsMissingEntirely() {
        let received = rejectedReply(to: ["PushActionInfo": info().toJSON()])

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
    }

    func testForwardsTheReplyAndAnswersSuccess() {
        let received = forwardedReply(to: forwardableContent(textInput: "on my way"))

        XCTAssertEqual(received["fired"] as? Bool, true)
        XCTAssertNil(received["error"])
        XCTAssertEqual(api.receivedInfo?.identifier, "REPLY")
        XCTAssertEqual(api.receivedInfo?.category, "DYNAMIC")
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }

    /// The watch used to read a reply as delivered whatever happened on the phone, because the old
    /// handler answered from `ensure`.
    func testAnswersFailureWhenHomeAssistantRejects() {
        api.failure = FakePushActionAPI.TestError.any

        let received = forwardedReply(to: forwardableContent(textInput: "on my way"))

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }
}

private final class FakePushActionAPI: HomeAssistantAPI {
    enum TestError: Error {
        case any
    }

    /// Set before the call to make Home Assistant reject the action.
    var failure: Error?
    private(set) var receivedInfo: PushActionInfo?

    override func handlePushAction(for info: PushActionInfo) -> Promise<Void> {
        receivedInfo = info

        if let failure {
            return Promise(error: failure)
        }
        return .value(())
    }
}
