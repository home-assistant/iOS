import HAKit
@testable import HomeAssistant
import XCTest

/// `camera/webrtc/get_client_config` is how a user's own STUN/TURN servers — from go2rtc or Home
/// Assistant Cloud — reach the client, which is what a remote camera needs to connect at all.
final class WebRTCClientConfigurationTests: XCTestCase {
    func testReadsTheICEServersTheBackendConfigured() {
        let configuration = WebRTCClientConfiguration(data: .init(value: [
            "configuration": [
                "iceServers": [
                    ["urls": "stun:stun.example.com:3478"],
                    ["urls": ["turn:turn.example.com:3478"], "username": "user", "credential": "secret"],
                ],
            ],
        ]))

        XCTAssertEqual(configuration.iceServers.count, 2)
        XCTAssertNil(configuration.dataChannelLabel)
    }

    /// Some cameras only start sending once the channel the backend named exists.
    func testReadsTheDataChannelLabel() {
        let configuration = WebRTCClientConfiguration(data: .init(value: [
            "configuration": ["iceServers": []],
            "dataChannel": "nest",
        ]))

        XCTAssertEqual(configuration.dataChannelLabel, "nest")
    }

    /// A backend that names no ICE servers still needs a way out of a NAT, so the app's own STUN
    /// servers stand in rather than leaving the connection with nothing to try.
    func testFallsBackToTheDefaultSTUNServersWhenNoneAreConfigured() {
        let configuration = WebRTCClientConfiguration(data: .init(value: [
            "configuration": ["iceServers": []],
        ]))

        XCTAssertEqual(configuration.iceServers.count, WebRTCClientConfiguration.fallback.iceServers.count)
    }

    /// An entry the app can't read a URL out of is skipped rather than taking the rest with it.
    func testSkipsServersWithoutUsableURLs() {
        let configuration = WebRTCClientConfiguration(data: .init(value: [
            "configuration": [
                "iceServers": [
                    ["urls": 42],
                    ["urls": "stun:stun.example.com:3478"],
                ],
            ],
        ]))

        XCTAssertEqual(configuration.iceServers.count, 1)
    }

    func testAResponseWithoutAConfigurationFallsBackEntirely() {
        let configuration = WebRTCClientConfiguration(data: .init(value: [String: Any]()))

        XCTAssertEqual(configuration.iceServers.count, WebRTCClientConfiguration.fallback.iceServers.count)
        XCTAssertNil(configuration.dataChannelLabel)
    }
}
