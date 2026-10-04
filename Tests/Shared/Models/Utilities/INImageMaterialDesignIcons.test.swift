#if os(iOS)
import Intents
@testable import Shared
import UIKit
import XCTest

final class INImageMaterialDesignIconsTests: XCTestCase {
    func testRendersIconIntoImage() {
        let image = INImage(icon: .accountIcon, foreground: .white, background: .black)
        XCTAssertNotNil(image)

        let other = INImage(icon: .abacusIcon, foreground: .red, background: .clear)
        XCTAssertNotEqual(image, other)
    }
}
#endif
