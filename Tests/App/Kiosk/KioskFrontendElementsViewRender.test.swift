@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

@MainActor
struct KioskFrontendElementsViewRenderTests {
    /// Lays the view out in a window, which is what makes SwiftUI evaluate the body.
    ///
    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests. The window is torn down again for
    /// the same reason.
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func rendersEveryElementWithTheDefaultsSelected() {
        render(NavigationView {
            KioskFrontendElementsView(hiddenElements: .constant(KioskFrontendElement.defaultHidden))
        })
    }

    @Test func rendersWithNothingSelected() {
        render(NavigationView {
            KioskFrontendElementsView(hiddenElements: .constant([]))
        })
    }

    /// The toggles write straight through the binding, which is what the settings screen persists.
    @Test func togglingAnElementWritesThroughTheBinding() {
        var hidden: Set<KioskFrontendElement> = []
        let binding = Binding(get: { hidden }, set: { hidden = $0 })

        render(NavigationView { KioskFrontendElementsView(hiddenElements: binding) })

        binding.wrappedValue.insert(.dashboardTabs)
        #expect(hidden == [.dashboardTabs])

        binding.wrappedValue.remove(.dashboardTabs)
        #expect(hidden.isEmpty)
    }
}
