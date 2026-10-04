#if os(iOS)
@testable import Shared
import UIKit
import XCTest

@MainActor
final class OnboardingStyleTests: XCTestCase {
    func testTitleStyle() {
        let label = UILabel()

        Style().onboardingTitle(label)

        XCTAssertEqual(label.textAlignment, .center)
        XCTAssertEqual(label.numberOfLines, 0)
        XCTAssertEqual(label.textColor, .label)
        XCTAssertTrue(label.accessibilityTraits.contains(.header))
    }

    func testPrimaryButtonStyle() {
        let button = UIButton(type: .system)

        Style().onboardingButtonPrimary(button)

        XCTAssertEqual(button.layer.cornerRadius, 12)
        XCTAssertTrue(button.layer.masksToBounds)
        XCTAssertNotNil(button.configuration)
        XCTAssertEqual(button.titleColor(for: .normal), .white)
        XCTAssertNotNil(button.backgroundImage(for: .normal))
        XCTAssertNotNil(button.backgroundImage(for: .highlighted))
        XCTAssertEqual(button.role, .primary)
    }

    func testSecondaryButtonStyle() {
        let button = UIButton(type: .system)

        Style().onboardingButtonSecondary(button)

        XCTAssertEqual(button.layer.cornerRadius, 12)
        XCTAssertEqual(button.titleColor(for: .normal), .white)
        XCTAssertNotNil(button.backgroundImage(for: .normal))
        XCTAssertNotNil(button.backgroundImage(for: .highlighted))
    }

    /// A plain `UIButton` is widened to the readable width once it is in a regular-width layout.
    func testPlainButtonFollowsTheReadableWidth() {
        let button = UIButton()

        Style().onboardingButtonPrimary(button)
        XCTAssertFalse(type(of: button) == UIButton.self)

        let container = UIView(frame: CGRect(x: 0, y: 0, width: 1024, height: 768))
        container.addSubview(button)
        XCTAssertTrue(button.superview === container)

        let regular = UITraitCollection(horizontalSizeClass: .regular)
        button.traitCollectionDidChange(regular)
        container.layoutIfNeeded()

        button.removeFromSuperview()
        XCTAssertNil(button.superview)
    }
}
#endif
