@testable import HomeAssistant
import UIKit
import WebKit
import XCTest

final class WebViewControllerTests: XCTestCase {
    func testMakeWebViewConfigurationRequiresUserActionForAudioPlayback() {
        let config = WebViewController.makeWebViewConfiguration()

        XCTAssertTrue(config.allowsInlineMediaPlayback)
        XCTAssertEqual(config.mediaTypesRequiringUserActionForPlayback, .audio)
    }

    func testMakeWebViewBottomConstraintAvoidsKeyboard() {
        let containerView = UIView()
        let webView = WKWebView(frame: .zero, configuration: WebViewController.makeWebViewConfiguration())

        let constraint = WebViewController.makeWebViewBottomConstraint(for: webView, in: containerView)

        XCTAssertIdentical(constraint.firstItem as? WKWebView, webView)
        XCTAssertEqual(constraint.firstAttribute, .bottom)
        XCTAssertEqual(constraint.relation, .equal)
        XCTAssertIdentical(constraint.secondItem as? UIView, containerView)
        XCTAssertEqual(constraint.secondAttribute, .bottom)
    }
}
