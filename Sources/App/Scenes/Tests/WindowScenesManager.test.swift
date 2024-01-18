@testable import HomeAssistant
import XCTest

final class WindowScenesManagerTests: XCTestCase {
    private var sut: WindowScenesManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = WindowScenesManager()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        sut = nil
    }

    func testSceneDidBecomeActiveStartObservingScene() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        firstScene.userActivity = nil
        sut.sceneDidBecomeActive(firstScene)

        XCTAssertEqual(sut.windowSizeObservers.count, 1)
    }

    func testDidDiscardSceneRemoveObserver() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        sut.didDiscardScene(firstScene)

        XCTAssertEqual(sut.windowSizeObservers.count, 0)
    }

    func testAdjustedSystemFrameReturnSameFrameForSingleScene() {
        let result = sut.adjustedSystemFrame(.zero, for: .zero, numberOfConnectedScenes: 1)

        XCTAssertEqual(result, .zero)
    }

    func testAdjustedSystemFrameReturnInsetedFrameForMultipleScenes() {
        let result = sut.adjustedSystemFrame(.zero, for: .zero, numberOfConnectedScenes: 2)

        XCTAssertEqual(result, .init(x: 20, y: 80, width: 0, height: 0))
    }

    func testSceneDidBecomeActiveNotConfigureScenesRestored() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        firstScene.userActivity = NSUserActivity(activityType: "test")
        sut.sceneDidBecomeActive(firstScene)

        XCTAssertEqual(sut.windowSizeObservers.count, 0)
    }
}
