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

    /// Runs the handler and returns the reply it produced. `settle` resolves the API promise for the
    /// cases that get that far.
    private func reply(to content: [String: Any], settle: (() -> Void)? = nil) -> [String: Any] {
        let replied = expectation(description: "replied")
        var received: [String: Any] = [:]

        service.pushAction(message: .init(
            identifier: InteractiveImmediateMessages.pushAction.rawValue,
            content: content,
            reply: { message in
                received = message.content
                replied.fulfill()
            }
        ))

        settle?()
        wait(for: [replied], timeout: 5)
        return received
    }

    func testRepliesFailureWhenThePayloadIsMissing() {
        let received = reply(to: [:])

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertNil(api.receivedInfo)
    }

    func testRepliesFailureWhenThePayloadCannotBeMapped() {
        let content: [String: Any] = ["PushActionInfo": ["nothing": "useful"]]

        let received = reply(to: content)

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertNil(api.receivedInfo)
    }

    func testRepliesFailureWhenTheServerIsUnknown() {
        let content: [String: Any] = [
            "PushActionInfo": info().toJSON(),
            "Server": "not-a-configured-server",
        ]

        let received = reply(to: content)

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertNil(api.receivedInfo)
    }

    func testRepliesFailureWhenTheServerIsMissingEntirely() {
        let content: [String: Any] = ["PushActionInfo": info().toJSON()]

        let received = reply(to: content)

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertNil(api.receivedInfo)
    }

    func testForwardsTheReplyAndAnswersSuccess() {
        let content: [String: Any] = [
            "PushActionInfo": info(textInput: "on my way").toJSON(),
            "Server": server.identifier.rawValue,
        ]

        let received = reply(to: content) { [weak self] in
            self?.api.resolver?.fulfill(())
        }

        XCTAssertEqual(received["fired"] as? Bool, true)
        XCTAssertNil(received["error"])
        XCTAssertEqual(api.receivedInfo?.identifier, "REPLY")
        XCTAssertEqual(api.receivedInfo?.category, "DYNAMIC")
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }

    /// The watch used to read a reply as delivered whatever happened on the phone, because the old
    /// handler answered from `ensure`.
    func testAnswersFailureWhenHomeAssistantRejects() {
        let content: [String: Any] = [
            "PushActionInfo": info(textInput: "on my way").toJSON(),
            "Server": server.identifier.rawValue,
        ]

        let received = reply(to: content) { [weak self] in
            self?.api.resolver?.reject(FakePushActionAPI.TestError.any)
        }

        XCTAssertEqual(received["fired"] as? Bool, false)
        XCTAssertNotNil(received["error"] as? String)
        XCTAssertEqual(api.receivedInfo?.textInput, "on my way")
    }
}

private final class FakePushActionAPI: HomeAssistantAPI {
    enum TestError: Error {
        case any
    }

    private(set) var receivedInfo: PushActionInfo?
    private(set) var resolver: Resolver<Void>?

    override func handlePushAction(for info: PushActionInfo) -> Promise<Void> {
        receivedInfo = info
        let (promise, resolver) = Promise<Void>.pending()
        self.resolver = resolver
        return promise
    }
}
