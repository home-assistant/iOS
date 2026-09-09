import Foundation
@testable import HomeAssistant
import Shared
import Testing
import UIKit

@MainActor
struct NativeTabBarFrontendSlotTests {
    private func makeSlot(
        controller: WebViewController?,
        isActive: Bool,
        onNeedsController: @escaping () -> Void = {}
    ) -> NativeTabBarFrontendSlot.SlotViewController {
        let slot = NativeTabBarFrontendSlot.SlotViewController()
        slot.loadViewIfNeeded()
        slot.update(controller: controller, isActive: isActive, onNeedsController: onNeedsController)
        return slot
    }

    @Test("The active slot adopts the frontend and the next active slot takes it over")
    func activeSlotAdoptsTheFrontend() {
        let controller = WebViewController(server: ServerFixture.standard)

        let first = makeSlot(controller: controller, isActive: true)
        #expect(controller.parent === first)
        #expect(controller.view.superview === first.view)

        let second = makeSlot(controller: controller, isActive: true)
        #expect(controller.parent === second)
        #expect(first.children.isEmpty)

        second.update(controller: controller, isActive: true, onNeedsController: {})
        #expect(controller.parent === second)
    }

    @Test("The hosting slot hands the web view's scroll view to the tab bar and lets go of it on detach")
    func contentScrollViewFollowsTheFrontend() {
        let controller = WebViewController(server: ServerFixture.standard)
        let slot = makeSlot(controller: controller, isActive: true)
        #expect(slot.contentScrollView(for: .bottom) === controller.webView.scrollView)

        slot.update(controller: nil, isActive: false, onNeedsController: {})
        #expect(slot.contentScrollView(for: .bottom) == nil)
    }

    @Test("A tapped tab bar spot becomes the next Assist zoom source, parked in the window at that frame")
    func assistZoomOrigin() {
        let controller = WebViewController(server: ServerFixture.standard)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        let frame = CGRect(x: 300, y: 780, width: 56, height: 56)

        controller.setAssistZoomOrigin(frame, in: window)
        let anchor = controller.pendingAssistZoomSourceView
        #expect(anchor?.frame == frame)
        #expect(anchor?.superview === window)

        controller.setAssistZoomOrigin(frame.offsetBy(dx: -100, dy: 0), in: window)
        #expect(controller.pendingAssistZoomSourceView === anchor)
        #expect(anchor?.frame.minX == 200)
        #expect(NativeTabBarButtonLocator.frame(ofButtonTitled: "Assist", in: window) == nil)
    }

    @Test("An inactive slot leaves the frontend alone")
    func inactiveSlotDoesNothing() {
        let controller = WebViewController(server: ServerFixture.standard)
        let slot = makeSlot(controller: controller, isActive: false)

        #expect(controller.parent == nil)
        #expect(slot.children.isEmpty)
    }

    @Test("A slot that is shown with no frontend asks for one")
    func activeSlotWithoutFrontendAsksForOne() async throws {
        var requests = 0
        let slot = makeSlot(controller: nil, isActive: true) { requests += 1 }

        try await Task.sleep(for: .milliseconds(50))
        #expect(requests == 1)
        #expect(slot.children.isEmpty)
    }

    @Test("A replaced frontend is detached from the slot that hosted the old one")
    func replacedFrontendIsDetached() {
        let old = WebViewController(server: ServerFixture.standard)
        let new = WebViewController(server: ServerFixture.standard)
        let slot = makeSlot(controller: old, isActive: true)

        slot.update(controller: new, isActive: true, onNeedsController: {})
        #expect(old.parent == nil)
        #expect(new.parent === slot)

        slot.update(controller: nil, isActive: false, onNeedsController: {})
        #expect(new.parent == nil)
        #expect(slot.children.isEmpty)
    }

    @Test("Appearing re-applies the pending frontend")
    func appearanceAppliesPendingFrontend() {
        let controller = WebViewController(server: ServerFixture.standard)
        let slot = makeSlot(controller: controller, isActive: true)
        let thief = makeSlot(controller: controller, isActive: true)
        #expect(controller.parent === thief)

        slot.viewWillAppear(false)
        #expect(controller.parent === slot)
    }
}
