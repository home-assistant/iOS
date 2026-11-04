import HAKit
@testable import HomeAssistant
import XCTest

/// WebRTC signaling rides the server's WebSocket, so what that socket's state means for a stream
/// about to be set up decides whether it is sent, held, or abandoned.
final class WebRTCServerConnectionReadinessTests: XCTestCase {
    func testAReadyConnectionCanCarrySignaling() {
        XCTAssertEqual(WebRTCServerConnectionReadiness(state: .ready(version: "2026.9.1")), .ready)
    }

    func testAConnectionOnItsWayUpIsWaitedFor() {
        XCTAssertEqual(WebRTCServerConnectionReadiness(state: .connecting), .waiting)
        XCTAssertEqual(WebRTCServerConnectionReadiness(state: .authenticating), .waiting)
    }

    /// The state a socket lands in after the network moves under it. Nothing sent now is answered,
    /// which is the whole reason the gate exists.
    func testAConnectionRetryingAfterANetworkChangeIsWaitedFor() {
        let state = HAConnectionState.disconnected(reason: .waitingToReconnect(
            lastError: nil,
            atLatest: Date(),
            retryCount: 1
        ))

        XCTAssertEqual(WebRTCServerConnectionReadiness(state: state), .waiting)
    }

    func testAnIdleConnectionNeedsANudgeBecauseNothingElseWillBringItBack() {
        XCTAssertEqual(WebRTCServerConnectionReadiness(state: .disconnected(reason: .disconnected)), .needsConnect)
    }

    func testARejectedConnectionIsNotWorthWaitingFor() {
        XCTAssertEqual(WebRTCServerConnectionReadiness(state: .disconnected(reason: .rejected)), .unusable)
    }
}
