@testable import HomeAssistant
import Shared
import SharedTesting
import SwiftUI
import Testing

struct WidgetStateColorRuleEditorTests {
    @MainActor
    @Test func editorSnapshot() {
        let rule = WidgetStateColorRule(
            comparison: .lessThan,
            threshold: 0,
            color: "#FF0000",
            target: .state
        )

        assertLightDarkSnapshots(
            of: NavigationStack {
                WidgetStateColorRuleEditor(rule: rule) { _ in
                }
            },
            named: "editor"
        )
    }
}
