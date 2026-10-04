@testable import Shared
import SwiftUI
import Testing
import UIKit

/// Lays the Dynamic Island toast out in a hosting controller, which is what makes SwiftUI evaluate
/// its body (including the `GeometryReader` content) without comparing any pixels.
@MainActor
struct ToastViewTests {
    private func layOut(_ view: some View, topSafeArea: CGFloat = 0) -> CGSize {
        let controller = UIHostingController(rootView: view)
        controller.additionalSafeAreaInsets = UIEdgeInsets(top: topSafeArea, left: 0, bottom: 0, right: 0)
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        return controller.sizeThatFits(in: CGSize(width: 390, height: 844))
    }

    @available(iOS 18, *)
    @Test func expandedToastLaysOut() {
        let view = ToastView(toast: .example1, isExpanded: true)

        #expect(view.isExpanded)
        #expect(view.toast?.title == "Transaction Success!")
        #expect(layOut(view).width > 0)
        #expect(layOut(view, topSafeArea: 59).width > 0)
    }

    @available(iOS 18, *)
    @Test func collapsedToastLaysOut() {
        let view = ToastView(toast: .example2, isExpanded: false)

        #expect(!view.isExpanded)
        #expect(layOut(view).width > 0)
        #expect(layOut(view, topSafeArea: 62).width > 0)
    }

    @available(iOS 18, *)
    @Test func withoutAToastOnlyTheShapeIsLaidOut() {
        let view = ToastView(toast: nil, isExpanded: false)

        #expect(view.toast == nil)
        #expect(layOut(view).width > 0)
    }

    @available(iOS 18, *)
    @Test func contentLaysOutWithAndWithoutADynamicIsland() {
        let view = ToastView(toast: .example1, isExpanded: true)

        #expect(layOut(view.ToastContent(true)).height > 0)
        #expect(layOut(view.ToastContent(false)).height > 0)
    }

    @available(iOS 18, *)
    @Test func overlayLeavesTheContentItIsAttachedTo() {
        let size = layOut(Text(verbatim: "Content").toastOverlay())

        #expect(size.width > 0)
        #expect(size.height > 0)
    }
}
