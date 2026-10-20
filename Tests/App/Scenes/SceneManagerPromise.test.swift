@testable import HomeAssistant
@testable import Shared
import UIKit
import XCTest

/// What the scene manager's promises were first sealed with must be released once replaced.
@MainActor
final class SceneManagerPromiseTests: XCTestCase {
    private var sut: SceneManager!

    override func setUp() {
        super.setUp()
        sut = SceneManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testTheFirstControllerIsReleasedOnceAnotherReplacesIt() {
        weak var first: WebViewController?
        // UIKit autoreleases during init, so drain before asserting.
        autoreleasepool {
            let controller = WebViewController(server: .fake())
            first = controller
            sut.setWebViewController(controller)
            sut.setWebViewController(WebViewController(server: .fake()))
        }

        XCTAssertNil(first)
    }

    /// The coordinator promise is sealed the same way, and a coordinator reaches its window's frontend.
    func testTheFirstCoordinatorIsReleasedOnceAnotherReplacesIt() {
        weak var first: MockAppCoordinator?
        autoreleasepool {
            let coordinator = MockAppCoordinator()
            first = coordinator
            sut.registerAppCoordinator(coordinator)
            sut.registerAppCoordinator(MockAppCoordinator())
        }

        XCTAssertNil(first)
    }
}
