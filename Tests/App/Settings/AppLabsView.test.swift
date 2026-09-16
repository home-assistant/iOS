@testable import HomeAssistant
import Shared
import SwiftUI
import Testing
import UIKit

struct AppLabsViewTests {
    @Test func appLabsIsHiddenOutsideTestFlight() {
        let previousIsTestFlight = Current.isTestFlight
        defer { Current.isTestFlight = previousIsTestFlight }

        Current.isTestFlight = false
        #expect(!SettingsItem.appLabs.isVisible)
        #expect(!AppLabsFeature.macNativeSidebar.isEnabled)

        Current.isTestFlight = true
        #expect(SettingsItem.appLabs.isVisible)
    }

    /// Lays the screen out so SwiftUI evaluates its body. Deliberately never becomes the key
    /// window: the snapshot helpers draw into whatever window is key, so stealing it here would
    /// reach into unrelated tests.
    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 1400))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    /// A device with nothing experimental on offer says so instead of showing an empty list.
    @Test @MainActor func rendersTheEmptyStateWithoutFeatures() {
        render(AppLabsView(features: []))
    }

    @Test @MainActor func rendersEveryFeature() {
        render(AppLabsView(features: AppLabsFeature.allCases))
    }
}
