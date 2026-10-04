@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the keychain explorer out so it runs its (read-only) generic password query and builds the
/// list for whatever the test host's keychain holds — an empty state, a load error or grouped rows.
@MainActor
@Suite(.serialized)
struct KeychainExplorerViewRenderTests {
    @Test func rendersTheExplorer() {
        let controller = UIHostingController(rootView: NavigationView { KeychainExplorerView() })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        #expect(controller.sizeThatFits(in: CGSize(width: 390, height: 1400)).width > 0)

        window.isHidden = true
        window.rootViewController = nil
    }
}
