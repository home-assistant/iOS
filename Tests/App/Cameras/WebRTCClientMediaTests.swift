@testable import HomeAssistant
import WebRTC
import XCTest

final class WebRTCClientMediaTests: XCTestCase {
    private struct OfferedMedia: Equatable {
        let kind: String
        let direction: String?
    }

    private let configuration = WebRTCClientConfiguration(iceServers: [], dataChannelLabel: nil)

    func testThePlaybackClientOnlyReceives() throws {
        XCTAssertEqual(try offeredMedia(for: .playback), [
            .init(kind: "audio", direction: "recvonly"),
            .init(kind: "video", direction: "recvonly"),
        ])
    }

    func testTheMicrophoneClientOnlySendsAudio() throws {
        XCTAssertEqual(try offeredMedia(for: .microphone), [
            .init(kind: "audio", direction: "sendonly"),
        ])
    }

    func testOnlyClientsThatSendAudioRecordTheMicrophone() {
        XCTAssertFalse(WebRTCClientMedia.playback.recordsMicrophone)
        XCTAssertTrue(WebRTCClientMedia.microphone.recordsMicrophone)
    }

    private func offeredMedia(for media: WebRTCClientMedia) throws -> [OfferedMedia] {
        let client = WebRTCClient(configuration: configuration, media: media)
        defer { client.closeConnection() }
        let offered = expectation(description: "offer created")
        var sdp: String?
        client.offer { offer in
            sdp = offer
            offered.fulfill()
        }
        wait(for: [offered], timeout: 10)

        let directions: Set<String> = ["sendrecv", "sendonly", "recvonly", "inactive"]
        return try XCTUnwrap(sdp).components(separatedBy: "\r\nm=").dropFirst().map { section in
            let lines = section.components(separatedBy: "\r\n")
            let kind = String(lines[0].prefix { $0 != " " })
            let direction = lines
                .first { $0.hasPrefix("a=") && directions.contains(String($0.dropFirst(2))) }
                .map { String($0.dropFirst(2)) }
            return OfferedMedia(kind: kind, direction: direction)
        }
    }
}
