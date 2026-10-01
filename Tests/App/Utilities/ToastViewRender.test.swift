@testable import Shared
import SharedTesting
import SwiftUI
import Testing

/// Lays the toast out collapsed and expanded so both shapes of its background are built.
@MainActor
struct ToastViewRenderTests {
    @Test func rendersCollapsedAndExpanded() {
        guard #available(iOS 18, *) else { return }
        for isExpanded in [false, true] {
            renderInWindow(ToastView(toast: .example1, isExpanded: isExpanded), height: 300)
        }
    }
}
