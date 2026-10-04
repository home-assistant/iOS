@testable import Shared
import UIKit
import XCTest

@MainActor
final class UIViewControllerDismissAllTests: XCTestCase {
    func testWithNothingPresentedCallsCompletionImmediately() {
        let controller = UIViewController()
        var completed = false

        controller.dismissAllViewControllersAbove { completed = true }

        XCTAssertTrue(completed)
    }

    func testWithoutCompletionDoesNothing() {
        let controller = UIViewController()
        controller.dismissAllViewControllersAbove()
        XCTAssertNil(controller.presentedViewController)
    }
}
