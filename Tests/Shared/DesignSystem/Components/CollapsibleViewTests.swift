@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct CollapsibleViewTests {
    @MainActor
    @Test func testCollapsibleViewCollapsed() async throws {
        let view = CollapsibleView {
            Text("This is a header")
        } expandedContent: {
            Text("This is a content")
        }

        assertLightDarkSnapshots(of: view)
    }

    @MainActor
    @Test func testCollapsibleViewOpen() async throws {
        let view = CollapsibleView(startExpanded: true) {
            Text("This is a header")
        } expandedContent: {
            Text("This is a content")
        }

        assertLightDarkSnapshots(of: view)
    }
}
