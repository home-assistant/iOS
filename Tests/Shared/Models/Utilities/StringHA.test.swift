import Foundation
@testable import Shared
import XCTest

final class StringHATests: XCTestCase {
    func testDJB2Hash() {
        XCTAssertEqual("".djb2hash, 5381)
        XCTAssertEqual("a".djb2hash, 5381 * 33 + 97)
        XCTAssertEqual("ab".djb2hash, (5381 * 33 + 97) * 33 + 98)
        XCTAssertNotEqual("ab".djb2hash, "ba".djb2hash)
    }

    func testContainsJinjaTemplate() {
        XCTAssertTrue("{{ states('sun.sun') }}".containsJinjaTemplate)
        XCTAssertTrue("{% if true %}yes{% endif %}".containsJinjaTemplate)
        XCTAssertTrue("{# comment #}".containsJinjaTemplate)
        XCTAssertFalse("plain { text }".containsJinjaTemplate)
    }

    func testCapitalizingFirstCharacterOnly() {
        XCTAssertEqual("hello world".capitalizedFirst, "Hello world")
        XCTAssertEqual("hELLO".capitalizedFirst, "HELLO")
        XCTAssertEqual("".capitalizedFirst, "")
        XCTAssertEqual("über".leadingCapitalized, "Über")
        XCTAssertEqual("".leadingCapitalized, "")
    }

    func testNilIfEmpty() {
        XCTAssertNil("".nilIfEmpty)
        XCTAssertEqual("value".nilIfEmpty, "value")
    }

    func testNilIfEmptyUnlessTranslationKey() {
        XCTAssertNil("".nilIfEmptyUnlessTranslationKey)
        XCTAssertNil("component.light.title".nilIfEmptyUnlessTranslationKey)
        XCTAssertNil("component::light::title".nilIfEmptyUnlessTranslationKey)
        XCTAssertEqual("Kitchen light".nilIfEmptyUnlessTranslationKey, "Kitchen light")
    }

    func testApplyingPlaceholders() {
        let template = "Turn {entity} to {state}, {entity}!"
        XCTAssertEqual(
            template.applying(placeholders: ["entity": "Lamp", "state": "on"]),
            "Turn Lamp to on, Lamp!"
        )
        XCTAssertEqual(template.applying(placeholders: [:]), template)
    }

    func testOptionalOrEmpty() {
        let missing: String? = nil
        let present: String? = "value"
        XCTAssertEqual(missing.orEmpty, "")
        XCTAssertEqual(present.orEmpty, "value")
    }
}
