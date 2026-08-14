@testable import Shared
import XCTest

class ConfigFlowOutcomeTests: XCTestCase {
    func testFormWithoutErrors() throws {
        let outcome = try ConfigFlowOutcome(json: [
            "type": "form",
            "flow_id": "abc123",
            "step_id": "user",
        ])
        XCTAssertEqual(outcome, .form(flowID: "abc123", errors: [:]))
    }

    func testFormWithErrors() throws {
        let outcome = try ConfigFlowOutcome(json: [
            "type": "form",
            "flow_id": "abc123",
            "errors": ["base": "cannot_connect"],
        ])
        XCTAssertEqual(outcome, .form(flowID: "abc123", errors: ["base": "cannot_connect"]))
    }

    func testFormWithoutFlowIdentifierThrows() {
        XCTAssertThrowsError(try ConfigFlowOutcome(json: ["type": "form"])) { error in
            XCTAssertEqual(error as? HomeAssistantConfigFlowError, .unexpectedResponse)
        }
    }

    func testCreateEntry() throws {
        let outcome = try ConfigFlowOutcome(json: [
            "type": "create_entry",
            "title": "iPhone Camera",
        ])
        XCTAssertEqual(outcome, .created(title: "iPhone Camera"))
    }

    func testAbort() throws {
        let outcome = try ConfigFlowOutcome(json: [
            "type": "abort",
            "reason": "already_configured",
        ])
        XCTAssertEqual(outcome, .aborted(reason: "already_configured"))
    }

    func testUnknownTypeThrows() {
        XCTAssertThrowsError(try ConfigFlowOutcome(json: ["type": "progress"])) { error in
            XCTAssertEqual(error as? HomeAssistantConfigFlowError, .unexpectedResponse)
        }
    }

    func testNonEnvelopeThrows() {
        XCTAssertThrowsError(try ConfigFlowOutcome(json: ["message": "unauthorized"])) { error in
            XCTAssertEqual(error as? HomeAssistantConfigFlowError, .unexpectedResponse)
        }
    }
}
