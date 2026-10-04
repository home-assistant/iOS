@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

#if os(iOS) && !targetEnvironment(macCatalyst)
/// The YAML viewer lets the user select and copy the sample payload, so the highlighter must never add
/// or drop a character, and each token kind must keep its own color.
struct YAMLSyntaxHighlighterTests {
    private typealias ForegroundColor = AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute

    @available(iOS 17.2, *)
    @Test func highlightingPreservesEveryCharacter() {
        let yaml = """
        # Run as a Script.
        sequence:
          - action: notify.mobile_app_<your_device>
            data:
              message: "Hello"
              progress: 42
              live_update: true
          - delay: { seconds: 3 }
          -
        plain line without separator
        """
        let highlighted = YAMLSyntaxHighlighter.highlight(yaml)
        #expect(String(highlighted.characters) == yaml)
    }

    @available(iOS 17.2, *)
    @Test func emptyInputStaysEmpty() {
        #expect(String(YAMLSyntaxHighlighter.highlight("").characters).isEmpty)
    }

    @available(iOS 17.2, *)
    @Test func commentsAreSecondary() {
        let highlighted = YAMLSyntaxHighlighter.highlight("  # a comment: with colon")
        #expect(color(of: "# a comment: with colon", in: highlighted) == Color(uiColor: .secondaryLabel))
        // The indentation is re-emitted unstyled.
        let indentEnd = highlighted.index(highlighted.startIndex, offsetByCharacters: 2)
        #expect(highlighted[highlighted.startIndex ..< indentEnd][ForegroundColor.self] == nil)
    }

    @available(iOS 17.2, *)
    @Test func keysAndScalarValuesUseTheirTokenColors() {
        let highlighted = YAMLSyntaxHighlighter.highlight(
            [
                "message: \"Hi there\"",
                "progress: 42",
                "enabled: true",
                "service: notify.phone",
            ].joined(separator: "\n")
        )
        #expect(color(of: "message", in: highlighted) == Color(uiColor: .systemBlue))
        #expect(color(of: "\"Hi there\"", in: highlighted) == Color(uiColor: .systemGreen))
        #expect(color(of: "42", in: highlighted) == Color(uiColor: .systemPurple))
        #expect(color(of: "true", in: highlighted) == Color(uiColor: .systemOrange))
        #expect(color(of: "notify.phone", in: highlighted) == Color(uiColor: .label))
        #expect(color(of: ":", in: highlighted) == Color(uiColor: .secondaryLabel))
    }

    @available(iOS 17.2, *)
    @Test func listMarkersArePunctuation() {
        let highlighted = YAMLSyntaxHighlighter.highlight("- action: run\n-")
        #expect(color(of: "- ", in: highlighted) == Color(uiColor: .secondaryLabel))
        #expect(color(of: "action", in: highlighted) == Color(uiColor: .systemBlue))
        #expect(color(of: "run", in: highlighted) == Color(uiColor: .label))
        #expect(String(highlighted.characters) == "- action: run\n-")
    }

    @available(iOS 17.2, *)
    @Test func flowMapsColorKeysNumbersAndBraces() {
        let highlighted = YAMLSyntaxHighlighter.highlight("delay: { seconds: 3, on: yes, mode: fast }")
        #expect(color(of: "seconds", in: highlighted) == Color(uiColor: .systemBlue))
        #expect(color(of: "3", in: highlighted) == Color(uiColor: .systemPurple))
        #expect(color(of: "yes", in: highlighted) == Color(uiColor: .systemOrange))
        #expect(color(of: "fast", in: highlighted) == Color(uiColor: .label))
        #expect(color(of: "{", in: highlighted) == Color(uiColor: .secondaryLabel))
        #expect(color(of: "}", in: highlighted) == Color(uiColor: .secondaryLabel))
        #expect(color(of: ",", in: highlighted) == Color(uiColor: .secondaryLabel))
    }

    @available(iOS 17.2, *)
    @Test func linesWithoutAColonStayUnstyled() {
        let highlighted = YAMLSyntaxHighlighter.highlight("just text")
        #expect(color(of: "just text", in: highlighted) == nil)
    }

    @available(iOS 17.2, *)
    @Test func keysWithoutAValueKeepTheirColon() {
        let highlighted = YAMLSyntaxHighlighter.highlight("data:")
        #expect(color(of: "data", in: highlighted) == Color(uiColor: .systemBlue))
        #expect(String(highlighted.characters) == "data:")
    }

    private func color(of substring: String, in attributed: AttributedString) -> Color? {
        guard let range = attributed.range(of: substring) else { return nil }
        return attributed[range][ForegroundColor.self]
    }
}
#endif
