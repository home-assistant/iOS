@testable import HomeAssistant
import PromiseKit
import Shared
import XCTest

final class WebViewSceneDelegateTests: XCTestCase {
    private var sut: WebViewSceneDelegate!
    private var mockWindowController: MockWebViewWindowControllerForSceneDelegate!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = WebViewSceneDelegate()
        mockWindowController = MockWebViewWindowControllerForSceneDelegate()
        sut.windowController = mockWindowController
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        sut = nil
        mockWindowController = nil
    }

    func testSceneDidEnterBackgroundRecordsTimestamp() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }
        let beforeTimestamp = Date()

        // When
        sut.sceneDidEnterBackground(firstScene)

        // Then
        let backgroundTimestamp = sut.value(forKey: "backgroundTimestamp") as? Date
        XCTAssertNotNil(backgroundTimestamp)
        XCTAssertGreaterThanOrEqual(backgroundTimestamp ?? Date.distantPast, beforeTimestamp)
    }

    func testSceneDidBecomeActiveWithNoBackgroundTimestampDoesNotRefresh() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait briefly to ensure any async operations complete
        let expectation = self.expectation(description: "Wait for potential refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertFalse(mockWindowController.mockWebViewController.refreshCalled)
    }

    func testSceneDidBecomeActiveWithLessThan5MinutesDoesNotRefresh() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Set background timestamp to 1 minute ago
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        sut.setValue(oneMinuteAgo, forKey: "backgroundTimestamp")

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait briefly to ensure any async operations complete
        let expectation = self.expectation(description: "Wait for potential refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertFalse(mockWindowController.mockWebViewController.refreshCalled)
    }

    func testSceneDidBecomeActiveWithMoreThan5MinutesTriggersRefresh() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Set background timestamp to 6 minutes ago
        let sixMinutesAgo = Date().addingTimeInterval(-360)
        sut.setValue(sixMinutesAgo, forKey: "backgroundTimestamp")

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait for async refresh to be triggered
        let expectation = self.expectation(description: "Wait for refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertTrue(mockWindowController.mockWebViewController.refreshCalled)
    }

    func testSceneDidBecomeActiveClearsBackgroundTimestamp() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Set background timestamp
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        sut.setValue(fiveMinutesAgo, forKey: "backgroundTimestamp")

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait briefly to ensure timestamp is cleared
        let expectation = self.expectation(description: "Wait for timestamp clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        let backgroundTimestamp = sut.value(forKey: "backgroundTimestamp") as? Date
        XCTAssertNil(backgroundTimestamp)
    }
}

// MARK: - Mock Classes

final class MockWebViewWindowControllerForSceneDelegate: WebViewWindowController {
    let mockWebViewController: MockWebViewController

    init() {
        let window = UIWindow()
        mockWebViewController = MockWebViewController()
        super.init(window: window, restorationActivity: nil)

        // Override the promise to return our mock
        webViewControllerPromise = .value(mockWebViewController)
    }
}
