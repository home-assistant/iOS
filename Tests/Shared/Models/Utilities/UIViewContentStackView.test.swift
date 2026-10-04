#if os(iOS)
@testable import Shared
import UIKit
import XCTest

@MainActor
final class UIViewContentStackViewTests: XCTestCase {
    func testScrollingStackViewIsEmbeddedInScrollView() throws {
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        let (scrollView, stackView, _) = UIView.contentStackView(in: superview, scrolling: true)

        let scroll = try XCTUnwrap(scrollView)
        XCTAssertIdentical(scroll.superview, superview)
        XCTAssertIdentical(stackView.superview, scroll)
        XCTAssertFalse(scroll.translatesAutoresizingMaskIntoConstraints)
        XCTAssertEqual(scroll.contentInsetAdjustmentBehavior, .always)
        XCTAssertFalse(scroll.delaysContentTouches)

        XCTAssertEqual(stackView.axis, .vertical)
        XCTAssertEqual(stackView.alignment, .center)
        XCTAssertEqual(stackView.spacing, 16)
        XCTAssertTrue(stackView.isLayoutMarginsRelativeArrangement)
        XCTAssertEqual(
            stackView.directionalLayoutMargins,
            NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        )
        XCTAssertFalse(stackView.translatesAutoresizingMaskIntoConstraints)

        superview.layoutIfNeeded()
        XCTAssertEqual(scroll.frame, superview.bounds)
    }

    func testNonScrollingStackViewFillsSuperview() {
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        let (scrollView, stackView, _) = UIView.contentStackView(in: superview, scrolling: false)

        XCTAssertNil(scrollView)
        XCTAssertIdentical(stackView.superview, superview)
        XCTAssertFalse(stackView.translatesAutoresizingMaskIntoConstraints)

        superview.layoutIfNeeded()
        XCTAssertEqual(stackView.frame, superview.bounds)
    }

    func testEqualSpacersMatchHeights() {
        let superview = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let (_, stackView, spacers) = UIView.contentStackView(in: superview, scrolling: false)

        let top = spacers.next()
        let label = UILabel()
        label.text = "Content"
        let bottom = spacers.next()

        XCTAssertNotIdentical(top, bottom)
        XCTAssertEqual(top.contentHuggingPriority(for: .vertical), .defaultLow)
        XCTAssertEqual(top.contentHuggingPriority(for: .horizontal), .defaultLow)

        stackView.addArrangedSubview(top)
        stackView.addArrangedSubview(label)
        stackView.addArrangedSubview(bottom)

        // Moving into the stack view (which owns the layout guide) pins the spacer's height to it.
        XCTAssertTrue(hasHeightConstraint(on: top, in: stackView))
        XCTAssertTrue(hasHeightConstraint(on: bottom, in: stackView))

        superview.layoutIfNeeded()
        XCTAssertEqual(top.frame.height, bottom.frame.height, accuracy: 0.5)
        XCTAssertGreaterThan(top.frame.height, 0)
    }

    func testSpacerOutsideOwningViewHasNoHeightConstraint() {
        let owner = UIView()
        let spacers = UIView.EqualSpacers(containerView: owner)
        let spacer = spacers.next()
        let otherContainer = UIView()

        otherContainer.addSubview(spacer)

        XCTAssertFalse(hasHeightConstraint(on: spacer, in: otherContainer))
        XCTAssertFalse(hasHeightConstraint(on: spacer, in: spacer))
    }

    private func hasHeightConstraint(on view: UIView, in container: UIView) -> Bool {
        container.constraints.contains { constraint in
            constraint.firstItem === view && constraint.firstAttribute == .height
        }
    }
}
#endif
