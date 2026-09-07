@testable import HomeAssistant
import XCTest

/// The peer connection the app offers with. It only ever receives, and it reports the liveness the
/// player uses to decide whether a stream survived being sent to the background.
final class WebRTCClientTests: XCTestCase {
    func testAFreshConnectionIsAliveAndSilent() {
        let client = WebRTCClient(configuration: .fallback)
        defer { client.closeConnection() }

        XCTAssertTrue(client.isConnectionAlive)
        XCTAssertTrue(client.isAudioMuted())
    }

    func testAClosedConnectionIsReportedAsNoLongerAlive() {
        let client = WebRTCClient(configuration: .fallback)

        client.closeConnection()

        XCTAssertFalse(client.isConnectionAlive)
    }

    /// Nothing is muted or unmuted until a remote audio track arrives, so asking before then must
    /// not claim the stream is audible.
    func testAudioIsReportedMutedUntilARemoteTrackArrives() {
        let client = WebRTCClient(configuration: .fallback)
        defer { client.closeConnection() }

        client.unmuteAudio()
        XCTAssertTrue(client.isAudioMuted())

        client.muteAudio()
        XCTAssertTrue(client.isAudioMuted())
    }

    /// The offer asks for both media kinds without offering to send any, which is what the frontend
    /// player negotiates and what the backends answer.
    func testTheOfferAsksForAudioAndVideoWithoutSendingEither() {
        let client = WebRTCClient(configuration: .fallback)
        defer { client.closeConnection() }

        let sdp = offer(from: client)

        XCTAssertTrue(sdp.contains("m=audio"))
        XCTAssertTrue(sdp.contains("m=video"))
        XCTAssertTrue(sdp.contains("a=recvonly"))
        XCTAssertFalse(sdp.contains("a=sendrecv"))
    }

    /// Some cameras — Nest among them — only start sending once the data channel the backend named
    /// has been opened, so the offer has to carry it.
    func testAConfiguredDataChannelIsOfferedToTheCamera() {
        let client = WebRTCClient(configuration: .init(
            iceServers: WebRTCClientConfiguration.fallback.iceServers,
            dataChannelLabel: "nest"
        ))
        defer { client.closeConnection() }

        let sdp = offer(from: client)

        XCTAssertTrue(sdp.contains("m=application"))
    }

    func testNoDataChannelIsOfferedWhenTheBackendDoesNotAskForOne() {
        let client = WebRTCClient(configuration: .fallback)
        defer { client.closeConnection() }

        let sdp = offer(from: client)

        XCTAssertFalse(sdp.contains("m=application"))
    }

    /// Creating the offer runs on WebRTC's own threads, so wait for it rather than reading whatever
    /// is there when the test looks.
    private func offer(from client: WebRTCClient) -> String {
        let created = expectation(description: "offer created")
        var sdp = ""
        client.offer { offered in
            sdp = offered
            created.fulfill()
        }
        wait(for: [created], timeout: 10)
        return sdp
    }
}
