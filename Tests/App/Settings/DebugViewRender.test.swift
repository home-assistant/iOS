@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

/// Lays the debugging screen out in a window, so beyond the rows built by its body SwiftUI also
/// evaluates the toolbar's export button, the share sheet binding and the keychain-deletion alert
/// modifier attached to the list.
@MainActor
struct DebugViewRenderTests {
    @Test func rendersTheScreenInANavigationView() {
        #expect(render(NavigationView { DebugView() }))
        #expect(!DebugView.settingsSearchEntries.isEmpty)
    }

    /// Deliberately never becomes the key window, so it can't leak into snapshot tests. Returns
    /// whether the hosted view was laid out in the window.
    private func render(_ view: some View) -> Bool {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let laidOut = controller.view.window === window

        window.isHidden = true
        window.rootViewController = nil
        return laidOut
    }
}
