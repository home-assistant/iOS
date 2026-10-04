@testable import HomeAssistant
import SwiftUI
import Testing
import UIKit

#if os(iOS) && !targetEnvironment(macCatalyst)
/// Lays the Live Activities settings screen out so SwiftUI evaluates its body: the status rows, the
/// empty active-activities state, the sync section and the samples link, whose destination builds the
/// whole static and animated sample catalog.
@MainActor
@Suite(.serialized)
struct LiveActivitySettingsViewRenderTests {
    @available(iOS 17.2, *)
    @Test func rendersTheScreenInsideANavigationStack() {
        #expect(render(NavigationStack { LiveActivitySettingsView() }))
    }

    @available(iOS 17.2, *)
    @Test func buildsTheBodyOutsideAWindow() {
        // Building the body constructs every section, including the samples destination.
        _ = LiveActivitySettingsView().body
        #expect(!LiveActivitySettingsView.settingsSearchEntries.isEmpty)
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
#endif
