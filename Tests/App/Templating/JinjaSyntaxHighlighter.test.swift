@testable import HomeAssistant
import Testing
import UIKit

/// The colours the template editor paints its source with.
struct JinjaSyntaxHighlighterTests {
    @Test func tintsDelimitersKeywordsAndStrings() {
        let text = "{{ states('light.kitchen') if true }}"

        let highlighted = JinjaSyntaxHighlighter.highlight(text, font: .systemFont(ofSize: 12))

        let colorAt: (Int)
            -> UIColor? = { highlighted.attribute(.foregroundColor, at: $0, effectiveRange: nil) as? UIColor }
        #expect(colorAt(0) == .systemPink)
        #expect(
            colorAt(text.distance(from: text.startIndex, to: text.range(of: "'light")!.lowerBound)) ==
                .systemOrange
        )
        #expect(colorAt(text.distance(from: text.startIndex, to: text.range(of: "true")!.lowerBound)) == .systemPurple)
    }

    /// An entity the editor knows about is drawn as a pill: filled, underlined and in the primary colour.
    @Test func drawsEntityReferencesAsPills() {
        let text = "{{ states('light.kitchen') }}"
        let range = (text as NSString).range(of: "light.kitchen")
        let reference = JinjaEntityReference(entityId: "light.kitchen", range: range)

        let highlighted = JinjaSyntaxHighlighter.highlight(
            text,
            font: .systemFont(ofSize: 12),
            entityReferences: [reference]
        )

        let attributes = highlighted.attributes(at: range.location, effectiveRange: nil)
        #expect(attributes[.backgroundColor] as? UIColor == UIColor.tertiaryFill)
        #expect(attributes[.foregroundColor] as? UIColor == UIColor.label)
        #expect(attributes[.underlineStyle] as? Int == NSUnderlineStyle.single.rawValue)
    }
}
