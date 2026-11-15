#if canImport(ActivityKit)
import Foundation
@testable import Shared
import XCTest

@available(iOS 17.2, *)
final class LiveActivityActionContractTests: XCTestCase {
    func testLiveActivityActionsSurviveLocalPushAndContentStateRoundTrip() throws {
        let event = try LocalPushEvent(data: .dictionary([
            "message": "Playing",
            "data": [
                "live_update": true,
                "tag": "music",
                "actions": [
                    ["action": "PLAY", "title": "Play", "icon": "sfsymbols:play.fill", "show_title": false],
                    ["action": "REPLY", "title": "Reply"],
                    ["action": "OPEN", "title": "Link", "uri": "/lovelace"],
                    ["action": "TEXT", "title": "Text", "behavior": "textInput"],
                    ["action": "PLAY", "title": "Duplicate"],
                    ["action": "PAUSE", "title": "Pause"],
                    ["action": "NEXT", "title": "Next"],
                    ["action": "EXTRA", "title": "Extra"],
                ],
            ],
        ]))
        let payload = try XCTUnwrap(event.contentWithoutServer.userInfo["homeassistant"] as? [String: Any])
        let state = HandlerStartOrUpdateLiveActivity.contentState(from: payload)
        XCTAssertEqual(state.actions.map(\.id), ["PLAY", "PAUSE", "NEXT"])
        XCTAssertEqual(state.actions.first?.systemImage, "play.fill")
        XCTAssertEqual(state.actions.first?.showTitle, false)
        XCTAssertNil(state.actions.last?.systemImage)
        XCTAssertNil(state.actions.last?.showTitle)

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(HALiveActivityAttributes.ContentState.self, from: encoded)
        XCTAssertEqual(decoded, state)
    }

    func testMissingOrMalformedRemoteActionsLeaveActivityContentReadable() throws {
        for json in [#"{"message":"Track"}"#, #"{"message":"Track","actions":{"title":"Play"}}"#] {
            let decoded = try JSONDecoder().decode(HALiveActivityAttributes.ContentState.self, from: Data(json.utf8))
            XCTAssertEqual(decoded.message, "Track")
            XCTAssertTrue(decoded.actions.isEmpty)
            let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
            XCTAssertNil(reencoded?["actions"])
        }
    }
}
#endif
