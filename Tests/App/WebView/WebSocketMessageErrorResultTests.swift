@testable import Shared
import XCTest

final class WebSocketMessageErrorResultTests: XCTestCase {
    func testAnErrorResultEncodesTheShapeTheFrontendRejectsWith() throws {
        let message = WebSocketMessage(id: 4, errorCode: "timeout", errorMessage: "Too slow")

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any]
        )

        XCTAssertEqual(json["id"] as? Int, 4)
        XCTAssertEqual(json["type"] as? String, "result")
        XCTAssertEqual(json["success"] as? Bool, false)
        XCTAssertEqual(json["error"] as? [String: String], ["code": "timeout", "message": "Too slow"])
        XCTAssertNil(json["result"])
    }

    func testAnErrorSurvivesDecoding() throws {
        let encoded = try JSONEncoder().encode(WebSocketMessage(id: 2, errorCode: "a", errorMessage: "b"))

        let decoded = try JSONDecoder().decode(WebSocketMessage.self, from: encoded)

        XCTAssertEqual(decoded.ID, 2)
        XCTAssertEqual(decoded.Success, false)
        XCTAssertEqual(decoded.ErrorInfo, ["code": "a", "message": "b"])
    }

    func testAnErrorIsReadFromTheFrontendsDictionary() {
        let message = WebSocketMessage([
            "id": 3,
            "type": "result",
            "success": false,
            "error": ["code": "unknown_command", "message": "Unknown command webrtc/stream/stopped"],
        ])

        XCTAssertEqual(message?.ErrorInfo?["code"], "unknown_command")
        XCTAssertEqual(message?.Success, false)
    }

    func testASuccessfulResultCarriesNoError() throws {
        let message = WebSocketMessage(id: 5, type: "result", result: [:])

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(message)) as? [String: Any]
        )

        XCTAssertEqual(json["success"] as? Bool, true)
        XCTAssertNil(json["error"])
    }
}
