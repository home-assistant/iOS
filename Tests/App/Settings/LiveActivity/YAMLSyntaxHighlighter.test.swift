#if os(iOS) && !targetEnvironment(macCatalyst)
@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// The highlighter only colors the YAML it is given: whatever the line looks like, the text that
/// comes out is the text that went in.
struct YAMLSyntaxHighlighterTests {
    @available(iOS 17.2, *)
    @Test(arguments: [
        "  -",
        "plain text without a key",
        "data: {on: true, level: 3, mode: auto}",
        "# comment\n- item: \"quoted\"\nflag: yes\ncount: 12\nempty:",
    ])
    func keepsTheSourceText(_ yaml: String) {
        let highlighted = YAMLSyntaxHighlighter.highlight(yaml)
        #expect(String(highlighted.characters) == yaml)
    }

    /// A bare dash and a flow-map boolean get their own colors.
    @available(iOS 17.2, *)
    @Test func colorsTheDashAndFlowMapBooleans() {
        let dash = YAMLSyntaxHighlighter.highlight("-")
        #expect(dash.runs.first?.foregroundColor == Color(uiColor: .secondaryLabel))

        let flowMap = YAMLSyntaxHighlighter.highlight("data: {on: true}")
        let colors = flowMap.runs.compactMap(\.foregroundColor)
        #expect(colors.contains(Color(uiColor: .systemOrange)))
    }
}
#endif
