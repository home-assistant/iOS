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
                    [
                        "action": "PLAY", "title": "Play", "icon": "sfsymbols:play.fill",
                        "show_title": false, "authentication_required": false,
                    ],
                    ["action": "REPLY", "title": "Reply"],
                    ["action": "OPEN", "title": "Link", "uri": "/lovelace"],
                    ["action": "TEXT", "title": "Text", "behavior": "textInput"],
                    ["action": "PLAY", "title": "Duplicate"],
                    ["action": "PAUSE", "title": "Pause", "show_title": 0, "authentication_required": 0],
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
        XCTAssertNil(state.actions[1].showTitle)
        XCTAssertNil(state.actions.last?.systemImage)
        XCTAssertNil(state.actions.last?.showTitle)
        XCTAssertEqual(state.actions.map(\.authenticationRequired), [false, true, true])

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(HALiveActivityAttributes.ContentState.self, from: encoded)
        XCTAssertEqual(decoded, state)
    }

    func testMalformedRemoteEntriesPreserveValidButtons() throws {
        let data = Data("""
        {
          "message": "Track",
          "actions": [
            null,
            {"action":"MISSING_TITLE"},
            {"action":"OPEN","title":"Open","uri":"/lovelace"},
            {"action":"NO_URI","title":"Open","uri":null},
            {"action":"INPUT","title":"Reply","behavior":"textInput"},
            {"action":"PLAY","title":"Play","show_title":false,"authentication_required":false},
            {"action":"PLAY","title":"Duplicate"},
            {"action":"REPLY","title":"Reply"},
            {"action":"NEXT","title":"Next","show_title":0,"icon":[],"authentication_required":"false"},
            {"action":"STOP","title":"Stop","icon":"sfsymbols:","authentication_required":true},
            {"action":"EXTRA","title":"Extra"}
          ]
        }
        """.utf8)
        let state = try JSONDecoder().decode(HALiveActivityAttributes.ContentState.self, from: data)
        XCTAssertEqual(state.actions.map(\.id), ["PLAY", "NEXT", "STOP"])
        XCTAssertEqual(state.actions.first?.showTitle, false)
        XCTAssertNil(state.actions[1].showTitle)
        XCTAssertNil(state.actions[1].icon)
        XCTAssertNil(state.actions.last?.systemImage)
        XCTAssertEqual(state.actions.map(\.authenticationRequired), [false, true, true])
    }

    func testByteLimitsPreserveValidButtonsAndDropOversizedIcons() {
        let oversized = String(repeating: "é", count: 49)
        let state = HALiveActivityAttributes.ContentState(message: "Track", actions: [
            .init(id: String(repeating: "é", count: 33), title: "Too long"),
            .init(id: "LONG_TITLE", title: oversized),
            .init(id: "  ", title: "No ID"),
            .init(id: "NO_TITLE", title: "  "),
            .init(id: "NEXT", title: "Next", icon: oversized),
        ])
        XCTAssertEqual(state.actions.map(\.id), ["NEXT"])
        XCTAssertNil(state.actions.first?.icon)
    }

    func testLocalUpdateOnlyAddsButtonsFromTheActivityOwner() {
        let attributes = HALiveActivityAttributes(tag: "music", title: "Music", serverWebhookId: "owner")
        let state = HALiveActivityAttributes.ContentState(message: "Track", actions: [
            .init(id: "PLAY", title: "Play", authenticationRequired: false),
        ])
        for sender in ["owner", "other", "", nil] as [String?] {
            let update = LiveActivityRegistry.Update(state: state, relevanceScore: nil, serverWebhookId: sender)
            let result = update.content(after: nil, attributes: attributes).state
            XCTAssertEqual(result.message, "Track")
            XCTAssertEqual(result.actions, sender == "owner" ? state.actions : [])
        }
    }

    func testLocalUpdateDropsButtonsThatWouldOverflowActivityKit() throws {
        let attributes = HALiveActivityAttributes(tag: "music", title: "Music", serverWebhookId: "owner")
        let message = String(repeating: "x", count: 3950)
        let state = HALiveActivityAttributes.ContentState(message: message, actions: [
            .init(id: "PLAY", title: "Play"),
            .init(id: "NEXT", title: String(repeating: "x", count: 96)),
        ])
        let result = state.fittingActions(for: attributes, from: "owner")
        XCTAssertEqual(result.actions.map(\.id), ["PLAY"])
        XCTAssertEqual(result.message, message)
        let encoder = JSONEncoder()
        XCTAssertLessThanOrEqual(try encoder.encode(result).count + encoder.encode(attributes).count, 4096)
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
