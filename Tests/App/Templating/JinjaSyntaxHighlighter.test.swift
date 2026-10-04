@testable import HomeAssistant
import UIKit
import XCTest

final class JinjaSyntaxHighlighterTests: XCTestCase {
    private let font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)

    func testLiteralTextIsSecondary() {
        let result = JinjaSyntaxHighlighter.highlight("Hello there", font: font)

        XCTAssertEqual(result.string, "Hello there")
        XCTAssertEqual(color(of: "Hello", in: result), .secondaryLabel)
        XCTAssertEqual(result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont, font)
    }

    func testExpressionPartsAreTinted() {
        let text = "Power {{ states('sensor.solar_power') | round(1) }} kW"
        let result = JinjaSyntaxHighlighter.highlight(text, font: font)

        XCTAssertEqual(color(of: "Power", in: result), .secondaryLabel)
        XCTAssertEqual(color(of: "{{", in: result), .systemPink)
        XCTAssertEqual(color(of: "}}", in: result), .systemPink)
        XCTAssertEqual(color(of: "|", in: result), .systemPink)
        XCTAssertEqual(color(of: "states", in: result), .systemTeal)
        XCTAssertEqual(color(of: "round", in: result), .systemTeal)
        XCTAssertEqual(color(of: "'sensor.solar_power'", in: result), .systemOrange)
        XCTAssertEqual(color(of: "1)", in: result), .systemBlue)
        XCTAssertEqual(color(of: "kW", in: result), .secondaryLabel)
    }

    func testStatementKeywordsAreTinted() {
        let text = "{% if is_state(\"light.kitchen\", \"on\") and true %}On{% endif %}"
        let result = JinjaSyntaxHighlighter.highlight(text, font: font)

        XCTAssertEqual(color(of: "{%", in: result), .systemPink)
        XCTAssertEqual(color(of: "if ", in: result), .systemPurple)
        XCTAssertEqual(color(of: "and", in: result), .systemPurple)
        XCTAssertEqual(color(of: "true", in: result), .systemPurple)
        XCTAssertEqual(color(of: "endif", in: result), .systemPurple)
        XCTAssertEqual(color(of: "\"light.kitchen\"", in: result), .systemOrange)
        XCTAssertEqual(color(of: "On{", in: result), .secondaryLabel)
    }

    func testAnUnterminatedExpressionIsStillHighlighted() {
        let text = "Now {{ now"
        let result = JinjaSyntaxHighlighter.highlight(text, font: font)

        XCTAssertEqual(color(of: "{{", in: result), .systemPink)
        XCTAssertEqual(color(of: "now", in: result), .label)
    }

    func testEntityReferencesAreUnderlined() {
        let text = "{{ states('light.kitchen') }}"
        let range = (text as NSString).range(of: "light.kitchen")
        let result = JinjaSyntaxHighlighter.highlight(
            text,
            font: font,
            entityReferences: [
                JinjaEntityReference(entityId: "light.kitchen", range: range),
                // Out of bounds, ignored rather than crashing.
                JinjaEntityReference(entityId: "light.gone", range: NSRange(location: 100, length: 5)),
            ]
        )

        XCTAssertEqual(
            result.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int,
            NSUnderlineStyle.single.rawValue
        )
        XCTAssertEqual(result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor, .label)
        XCTAssertNil(result.attribute(.underlineStyle, at: 0, effectiveRange: nil))
    }

    func testEntityReferenceKeepsItsDisplayNameAndSubtitle() {
        let reference = JinjaEntityReference(entityId: "light.kitchen", range: NSRange(location: 0, length: 13))
        XCTAssertEqual(reference.name, "light.kitchen")
        XCTAssertNil(reference.subtitle)

        let named = JinjaEntityReference(
            entityId: "light.kitchen",
            range: NSRange(location: 0, length: 13),
            name: "Kitchen",
            subtitle: "Ground floor"
        )
        XCTAssertEqual(named.name, "Kitchen")
        XCTAssertEqual(named.subtitle, "Ground floor")
        XCTAssertNotEqual(reference, named)
    }

    private func color(of substring: String, in result: NSAttributedString) -> UIColor? {
        let range = (result.string as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, "\(substring) is not in \(result.string)")
        guard range.location != NSNotFound else { return nil }
        return result.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
    }
}
