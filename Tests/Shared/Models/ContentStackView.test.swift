import Foundation
@testable import Shared
import Testing
import UIKit

/// `UIView.contentStackView(in:scrolling:)` and its equal spacers.
@MainActor
struct ContentStackViewTests {
    @Test func scrollingLayoutEmbedsTheStackInAScrollView() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let (scrollView, stackView, spacers) = UIView.contentStackView(in: container, scrolling: true)
        #expect(scrollView?.superview === container)
        #expect(stackView.superview === scrollView)
        #expect(stackView.axis == .vertical)

        let top = spacers.next()
        let bottom = spacers.next()
        stackView.addArrangedSubview(top)
        stackView.addArrangedSubview(UILabel())
        stackView.addArrangedSubview(bottom)
        container.layoutIfNeeded()
        #expect(top.superview === stackView)
        #expect(top.constraints.isEmpty || top.constraints.allSatisfy(\.isActive))
    }

    @Test func plainLayoutPinsTheStackToItsSuperview() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let (scrollView, stackView, spacers) = UIView.contentStackView(in: container, scrolling: false)
        #expect(scrollView == nil)
        #expect(stackView.superview === container)
        // A spacer added somewhere that doesn't own the guide stays unconstrained.
        let stray = spacers.next()
        container.addSubview(stray)
        container.layoutIfNeeded()
        #expect(stray.superview === container)
    }
}
