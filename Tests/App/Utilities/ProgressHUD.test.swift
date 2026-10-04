@testable import HomeAssistant
import UIKit
import XCTest

@MainActor
final class ProgressHUDTests: XCTestCase {
    func testShowsAnIndeterminateSpinnerByDefault() throws {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        let hud = ProgressHUD.showAdded(to: container, animated: false)
        hud.layoutIfNeeded()

        XCTAssertTrue(hud.superview === container)
        XCTAssertEqual(hud.frame, container.bounds)
        XCTAssertEqual(hud.alpha, 1)
        XCTAssertEqual(hud.mode, .indeterminate)
        let spinner = try XCTUnwrap(Self.activityIndicator(in: hud))
        XCTAssertFalse(spinner.isHidden)
        XCTAssertTrue(hud.label.isHidden, "no text, no label")
    }

    func testAnimatedShowFadesIn() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        let hud = ProgressHUD.showAdded(to: container, animated: true)

        XCTAssertTrue(hud.superview === container)
    }

    func testTextModeHidesTheSpinnerAndShowsTheLabel() throws {
        let hud = ProgressHUD(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

        hud.mode = .text
        hud.label.text = "Saved"

        XCTAssertEqual(try XCTUnwrap(Self.activityIndicator(in: hud)).isHidden, true)
        XCTAssertFalse(hud.label.isHidden)

        hud.label.text = ""
        XCTAssertTrue(hud.label.isHidden)
    }

    func testCustomViewModeShowsTheCustomView() throws {
        let hud = ProgressHUD(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let checkmark = UIImageView(frame: CGRect(x: 0, y: 0, width: 37, height: 37))

        hud.customView = checkmark
        hud.mode = .customView
        hud.layoutIfNeeded()

        let container = try XCTUnwrap(checkmark.superview)
        XCTAssertFalse(container.isHidden)
        XCTAssertTrue(try XCTUnwrap(Self.activityIndicator(in: hud)).isHidden)

        let replacement = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        hud.customView = replacement
        XCTAssertNil(checkmark.superview, "the previous custom view is removed")
        XCTAssertTrue(replacement.superview === container)

        hud.customView = nil
        XCTAssertTrue(container.isHidden)
    }

    func testHideRemovesTheHUD() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = ProgressHUD.showAdded(to: container, animated: false)

        hud.hide(animated: false)

        XCTAssertNil(hud.superview)
    }

    func testDelayedHideRemovesTheHUD() {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let hud = ProgressHUD.showAdded(to: container, animated: false)

        hud.hide(animated: false, afterDelay: 0.01)
        XCTAssertNotNil(hud.superview, "nothing happens before the delay")

        for _ in 0 ..< 100 where hud.superview != nil {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertNil(hud.superview)
    }

    func testBackgroundStyles() {
        let background = ProgressHUD.BackgroundView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))

        background.style = .blur
        XCTAssertEqual(background.subviews.compactMap { $0 as? UIVisualEffectView }.count, 1)
        background.style = .blur
        XCTAssertEqual(background.subviews.compactMap { $0 as? UIVisualEffectView }.count, 1, "blur is added once")

        background.style = .solidColor
        XCTAssertTrue(background.subviews.isEmpty)
        XCTAssertEqual(background.backgroundColor, .clear)
    }

    func testLabelReportsTextChanges() {
        let label = HUDLabel()
        var changes = 0
        label.onTextChange = { changes += 1 }

        label.text = "One"
        label.text = "Two"

        XCTAssertEqual(changes, 2)
    }

    private static func activityIndicator(in view: UIView) -> UIActivityIndicatorView? {
        for subview in view.subviews {
            if let indicator = subview as? UIActivityIndicatorView {
                return indicator
            }
            if let indicator = activityIndicator(in: subview) {
                return indicator
            }
        }
        return nil
    }
}
