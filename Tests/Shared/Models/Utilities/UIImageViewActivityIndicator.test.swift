#if os(iOS)
@testable import Shared
import UIKit
import XCTest

@MainActor
final class UIImageViewActivityIndicatorTests: XCTestCase {
    /// The extension defers its work onto the main operation queue, which runs operations in order.
    private func drainMainOperationQueue() {
        let drained = expectation(description: "main operation queue drained")
        OperationQueue.main.addOperation { drained.fulfill() }
        wait(for: [drained], timeout: 10)
    }

    private func indicators(in imageView: UIImageView) -> [UIActivityIndicatorView] {
        imageView.subviews.compactMap { $0 as? UIActivityIndicatorView }
    }

    func testShowAddsCenteredAnimatingIndicator() throws {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))

        imageView.showActivityIndicator()
        drainMainOperationQueue()

        let indicator = try XCTUnwrap(indicators(in: imageView).first)
        XCTAssertEqual(indicators(in: imageView).count, 1)
        XCTAssertTrue(indicator.isAnimating)
        XCTAssertTrue(indicator.hidesWhenStopped)
        XCTAssertFalse(indicator.isUserInteractionEnabled)
        XCTAssertEqual(indicator.style, .large)
        XCTAssertEqual(indicator.center, CGPoint(x: 100, y: 50))
        XCTAssertEqual(
            indicator.autoresizingMask,
            [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        )
    }

    func testShowTwiceReusesIndicator() {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))

        imageView.showActivityIndicator()
        imageView.showActivityIndicator()
        drainMainOperationQueue()

        XCTAssertEqual(indicators(in: imageView).count, 1)
    }

    func testHideStopsIndicator() throws {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))

        imageView.showActivityIndicator()
        drainMainOperationQueue()
        imageView.hideActivityIndicator()
        drainMainOperationQueue()

        let indicator = try XCTUnwrap(indicators(in: imageView).first)
        XCTAssertFalse(indicator.isAnimating)
        XCTAssertTrue(indicator.isHidden)
    }
}
#endif
