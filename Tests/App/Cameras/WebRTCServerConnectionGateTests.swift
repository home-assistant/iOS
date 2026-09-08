import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import XCTest

/// A camera stream set up while the server's WebSocket is down never gets an answer to anything it
/// sends, so the gate has to hold it until the socket is back — and let it go once it is.
final class WebRTCServerConnectionGateTests: XCTestCase {
    private var connection: HAMockConnection!
    private var gate: WebRTCServerConnectionGate!

    override func setUp() {
        super.setUp()
        connection = HAMockConnection()
        gate = WebRTCServerConnectionGate(connection: connection)
    }

    override func tearDown() {
        gate?.cancel()
        gate = nil
        connection = nil
        super.tearDown()
    }

    func testAConnectionThatIsAlreadyReadyLetsTheStreamStartImmediately() {
        connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)

        var result: Bool?
        gate.whenReady { result = $0 }

        XCTAssertEqual(result, true)
    }

    /// The case the device logs caught: the socket died with the Wi-Fi, HAKit had not noticed yet,
    /// and the stream that went out over it was answered by nothing at all.
    func testAStreamWaitsWhileTheConnectionIsComingBackAndStartsWhenItDoes() {
        connection.setState(.connecting, waitForQueue: false)

        var result: Bool?
        gate.whenReady { result = $0 }
        XCTAssertNil(result, "The stream should be held while the connection is not ready")

        let ready = expectation(description: "gate opens once the connection is ready")
        DispatchQueue.main.async {
            self.connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)
            DispatchQueue.main.async { ready.fulfill() }
        }
        wait(for: [ready], timeout: 2)

        XCTAssertEqual(result, true)
    }

    func testARejectedConnectionFailsTheStreamRatherThanWaitingOnIt() {
        connection.setState(.disconnected(reason: .rejected), waitForQueue: false)

        var result: Bool?
        gate.whenReady { result = $0 }

        XCTAssertEqual(result, false)
    }

    /// Nothing brings an idle socket back on its own, so the gate asks for it instead of waiting
    /// for a reconnect that was never scheduled. The connection reaching ready is what shows it
    /// asked — left alone, the mock stays disconnected forever.
    func testAnIdleConnectionIsReconnectedRatherThanWaitedOn() {
        connection.setState(.disconnected(reason: .disconnected), waitForQueue: false)

        let opened = expectation(description: "gate opens after asking for a reconnect")
        gate.whenReady { isReady in
            XCTAssertTrue(isReady)
            opened.fulfill()
        }

        wait(for: [opened], timeout: 2)
    }

    /// The failure the gate could not catch on its own: the phone left Wi-Fi five milliseconds
    /// after HAKit reported the socket ready, so the state said ready for a socket that was already
    /// dead and the command sent over it was never answered. Once signaling has stalled, a ready
    /// state is not evidence of anything until the connection has actually been re-established.
    func testAStaleReadyConnectionIsNotTrustedAfterSignalingHasStalled() {
        connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)

        var result: Bool?
        gate.whenReady(requiringFreshConnection: true) { result = $0 }

        XCTAssertNil(result, "A ready state that was already there proves nothing after a stall")
    }

    func testAConnectionThatDropsAndComesBackIsTrustedAgain() {
        connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)

        var result: Bool?
        gate.whenReady(requiringFreshConnection: true) { result = $0 }
        XCTAssertNil(result)

        let reconnected = expectation(description: "gate opens on a re-established connection")
        DispatchQueue.main.async {
            self.connection.setState(.connecting, waitForQueue: false)
            DispatchQueue.main.async {
                self.connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)
                DispatchQueue.main.async { reconnected.fulfill() }
            }
        }
        wait(for: [reconnected], timeout: 2)

        XCTAssertEqual(result, true)
    }

    func testACancelledGateNeverCallsBack() {
        connection.setState(.connecting, waitForQueue: false)

        var result: Bool?
        gate.whenReady { result = $0 }
        gate.cancel()

        let settled = expectation(description: "state change is observed")
        DispatchQueue.main.async {
            self.connection.setState(.ready(version: "2026.9.1"), waitForQueue: false)
            DispatchQueue.main.async { settled.fulfill() }
        }
        wait(for: [settled], timeout: 2)

        XCTAssertNil(result, "A torn-down stream should not be resumed by the gate")
    }
}
