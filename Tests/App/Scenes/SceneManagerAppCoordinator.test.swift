@testable import HomeAssistant
import UIKit
import XCTest

/// Multi-window runs one coordinator per scene, so a request that started in a window has to reach that
/// window's coordinator rather than whichever one registered last.
@MainActor
final class SceneManagerAppCoordinatorTests: XCTestCase {
    private var sut: SceneManager!

    override func setUp() {
        super.setUp()
        sut = SceneManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testCoordinatorForASceneIsTheOneShowingInThatScene() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let sceneCoordinator = MockAppCoordinator()
        sceneCoordinator.window = UIWindow(windowScene: scene)
        // Registered last, so it is the app-wide one; asking for the scene must still skip it.
        let otherCoordinator = MockAppCoordinator()
        otherCoordinator.window = UIWindow()

        sut.registerAppCoordinator(sceneCoordinator)
        sut.registerAppCoordinator(otherCoordinator)

        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator(for: scene).value), sceneCoordinator)
        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator.value), otherCoordinator)
    }

    func testCoordinatorFallsBackToTheAppWideOneWhenTheSceneHasNone() throws {
        let coordinator = MockAppCoordinator()
        sut.registerAppCoordinator(coordinator)

        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator(for: nil).value), coordinator)
    }

    func testCoordinatorForASceneNoneIsRegisteredForFallsBackToTheAppWideOne() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let coordinator = MockAppCoordinator()
        coordinator.window = UIWindow()
        sut.registerAppCoordinator(coordinator)

        XCTAssertIdentical(try XCTUnwrap(sut.appCoordinator(for: scene).value), coordinator)
    }
}
