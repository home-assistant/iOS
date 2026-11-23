import PromiseKit
@testable import Shared
import XCTest

final class IncomingCallCommandHandlerTests: XCTestCase {
    private var previousServers: ServerManager!
    private var rung: [IncomingCallRequest]!
    private var handler: IncomingCallCommandHandler!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        servers.addFake()
        Current.servers = servers
        rung = []
        handler = IncomingCallCommandHandler { [unowned self] request, _ in rung.append(request) }
    }

    override func tearDown() {
        Current.servers = previousServers
        super.tearDown()
    }

    // The handler settles synchronously, so its promise can be checked right away.
    func testRingsAValidCallFromAKnownServer() {
        XCTAssertTrue(handler.handle([
            "command": "incoming_call",
            "tag": "visio",
            "webhook_id": "FakeWebhookID",
            "url": "http://homeassistant.local:8123/visio",
        ]).isFulfilled)
        XCTAssertEqual(rung.map(\.tag), ["visio"])
        // An address of the server is kept as a path on it.
        XCTAssertEqual(rung.first?.url, "/visio")
    }

    func testIgnoresUnknownServers() {
        XCTAssertTrue(handler.handle([
            "command": "incoming_call",
            "tag": "visio",
            "webhook_id": "someone-else",
        ]).isRejected)
        XCTAssertTrue(handler.handle(["command": "incoming_call", "tag": "visio"]).isRejected)
        XCTAssertTrue(rung.isEmpty)
    }

    func testIgnoresInvalidCalls() {
        XCTAssertTrue(handler.handle([
            "command": "incoming_call",
            "tag": "not valid",
            "webhook_id": "FakeWebhookID",
        ]).isRejected)
        XCTAssertTrue(rung.isEmpty)
    }
}
