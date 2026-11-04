@testable import HomeAssistant
import XCTest

final class EntityControlMessageTests: XCTestCase {
    func testReadsEveryField() {
        let message = EntityControlMessage(payload: [
            "entity_ids": ["light.kitchen", "light.hall"],
            "domain": "light",
            "service": "turn_on",
        ])
        XCTAssertEqual(message?.entityIds, ["light.kitchen", "light.hall"])
        XCTAssertEqual(message?.domain, "light")
        XCTAssertEqual(message?.service, "turn_on")
    }

    func testRejectsIncompleteOrEmptyPayloads() {
        XCTAssertNil(EntityControlMessage(payload: nil))
        XCTAssertNil(EntityControlMessage(payload: ["entity_ids": [], "domain": "light", "service": "turn_on"]))
        XCTAssertNil(EntityControlMessage(payload: [
            "entity_ids": "light.kitchen",
            "domain": "light",
            "service": "turn_on",
        ]))
        XCTAssertNil(EntityControlMessage(payload: ["entity_ids": ["light.kitchen"], "service": "turn_on"]))
        XCTAssertNil(EntityControlMessage(payload: ["entity_ids": ["light.kitchen"], "domain": "light"]))
    }
}
