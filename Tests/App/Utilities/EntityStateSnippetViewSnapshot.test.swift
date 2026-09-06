@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

struct EntityStateSnippetViewSnapshotTests {
    private static let width: CGFloat = 340
    private static let height: CGFloat = 110

    @MainActor @Test func entityStateCard() {
        let view = EntityStateSnippetView(state: .previewLight)
            .frame(width: Self.width, height: Self.height)
            .background(Color(uiColor: .systemBackground))

        assertLightDarkSnapshots(
            of: view,
            drawHierarchyInKeyWindow: true,
            layout: .fixed(width: Self.width, height: Self.height)
        )
    }
}
