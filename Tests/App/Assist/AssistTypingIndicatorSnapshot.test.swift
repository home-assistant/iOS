@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

struct AssistTypingIndicatorSnapshotTests {
    private static let size: CGFloat = 80

    @available(iOS 18, *)
    @MainActor @Test func typingIndicator() {
        let view = AssistTypingIndicator()
            .frame(width: Self.size, height: Self.size)
            .background(Color(uiColor: .systemBackground))

        assertLightDarkSnapshots(
            of: view,
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.size, height: Self.size)
        )
    }
}
