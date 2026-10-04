#if os(iOS)
@testable import Shared
import UIKit
import XCTest

@MainActor
final class UIBarButtonItemIconTests: XCTestCase {
    @objc private func tapped() {}

    func testInitUsesIconImagesAndName() {
        let icon = MaterialDesignIcons.accountIcon
        let item = UIBarButtonItem(icon: icon, target: self, action: #selector(tapped))

        XCTAssertEqual(item.accessibilityLabel, icon.name)
        XCTAssertEqual(item.style, .plain)
        XCTAssertIdentical(item.target as AnyObject?, self)
        XCTAssertEqual(item.action, #selector(tapped))
        XCTAssertEqual(item.image?.size, CGSize(width: 28, height: 28))
        XCTAssertEqual(item.landscapeImagePhone?.size, CGSize(width: 20, height: 20))
    }
}
#endif
