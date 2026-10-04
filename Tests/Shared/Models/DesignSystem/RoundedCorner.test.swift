@testable import Shared
import SwiftUI
import Testing
import UIKit

struct RoundedCornerTests {
    private let rect = CGRect(x: 0, y: 0, width: 100, height: 50)

    @Test func defaultsRoundEveryCornerFully() {
        let shape = RoundedCorner()

        #expect(shape.radius == .infinity)
        #expect(shape.corners == .allCorners)
    }

    @Test func pathFillsTheRectItIsDrawnIn() {
        let path = RoundedCorner(radius: 10, corners: [.topLeft, .bottomRight]).path(in: rect)

        let bounds = path.boundingRect
        #expect(abs(bounds.minX - rect.minX) < 0.001)
        #expect(abs(bounds.minY - rect.minY) < 0.001)
        #expect(abs(bounds.width - rect.width) < 0.001)
        #expect(abs(bounds.height - rect.height) < 0.001)
        #expect(path.contains(CGPoint(x: 50, y: 25)))
    }

    @Test func onlyTheRequestedCornersAreRounded() {
        let path = RoundedCorner(radius: 20, corners: [.topLeft]).path(in: rect)

        // The rounded top-left corner cuts its tip off, while the square corners keep theirs.
        #expect(!path.contains(CGPoint(x: 1, y: 1)))
        #expect(path.contains(CGPoint(x: 99, y: 1)))
        #expect(path.contains(CGPoint(x: 1, y: 49)))
        #expect(path.contains(CGPoint(x: 99, y: 49)))
    }

    @MainActor
    @Test func modifierClipsTheViewWithoutChangingItsSize() {
        let controller = UIHostingController(
            rootView: Color.red
                .frame(width: 100, height: 50)
                .roundedCorner(12, corners: [.topLeft, .topRight])
        )
        controller.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        controller.view.layoutIfNeeded()

        let size = controller.sizeThatFits(in: CGSize(width: 200, height: 200))
        #expect(size == CGSize(width: 100, height: 50))
    }
}
