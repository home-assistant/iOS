@testable import HomeAssistant
import XCTest

final class WindowScenesManagerTests: XCTestCase {
    private var sut: WindowScenesManager!
    private var savedFrames: [SceneActivity: Data?] = [:]

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = WindowScenesManager()
        for activity in SceneActivity.allCases {
            savedFrames[activity] = prefs.data(forKey: ScenesWindowSizeConfig.key(for: activity))
            prefs.removeObject(forKey: ScenesWindowSizeConfig.key(for: activity))
        }
    }

    override func tearDownWithError() throws {
        for (activity, data) in savedFrames {
            if let data {
                prefs.set(data, forKey: ScenesWindowSizeConfig.key(for: activity))
            } else {
                prefs.removeObject(forKey: ScenesWindowSizeConfig.key(for: activity))
            }
        }
        savedFrames = [:]
        try super.tearDownWithError()
        sut = nil
    }

    func testSceneDidBecomeActiveStartObservingScene() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        sut.sceneDidBecomeActive(firstScene, activity: .webView)

        XCTAssertEqual(sut.windowSizeObservers.count, 1)
    }

    func testSceneDidBecomeActiveObservesSceneActivatedByUserActivity() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        firstScene.userActivity = NSUserActivity(activityType: "test")
        sut.sceneDidBecomeActive(firstScene, activity: .webView)

        XCTAssertEqual(sut.windowSizeObservers.count, 1)
    }

    func testSceneDidBecomeActiveTwiceDoesNotDuplicateObserver() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        sut.sceneDidBecomeActive(firstScene, activity: .webView)
        sut.sceneDidBecomeActive(firstScene, activity: .webView)

        XCTAssertEqual(sut.windowSizeObservers.count, 1)
    }

    func testSceneDidBecomeActiveObserverKeepsActivityOfItsWindow() {
        guard let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        sut.sceneDidBecomeActive(firstScene, activity: .assist)

        XCTAssertEqual(sut.windowSizeObservers.first?.activity, .assist)
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

    func testSystemFrameCentersDefaultSizeWhenAssistWindowWasNeverPlaced() {
        let result = sut.systemFrame(for: .assist, screenSize: .init(width: 1000, height: 1000))

        XCTAssertEqual(result, .init(x: 300, y: 200, width: 400, height: 600))
    }

    func testSystemFrameIsNilWhenMainWindowWasNeverPlaced() {
        let result = sut.systemFrame(for: .webView, screenSize: .init(width: 1000, height: 1000))

        XCTAssertNil(result)
    }

    func testSystemFrameUsesSavedFramePerActivity() {
        let assistFrame = CGRect(x: 12, y: 34, width: 300, height: 400)
        ScenesWindowSizeConfig.setLatestSystemFrame(assistFrame, for: .assist)

        XCTAssertEqual(sut.systemFrame(for: .assist, screenSize: .init(width: 1000, height: 1000)), assistFrame)
        XCTAssertNil(sut.systemFrame(for: .webView, screenSize: .init(width: 1000, height: 1000)))
    }

    func testSystemFrameFallsBackToDefaultWhenSavedFrameIsBiggerThanScreen() {
        ScenesWindowSizeConfig.setLatestSystemFrame(.init(x: 0, y: 0, width: 5000, height: 5000), for: .assist)

        let result = sut.systemFrame(for: .assist, screenSize: .init(width: 1000, height: 1000))

        XCTAssertEqual(result, .init(x: 300, y: 200, width: 400, height: 600))
    }
}
