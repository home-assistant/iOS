@testable import HomeAssistant
import PromiseKit
import Shared
import XCTest

final class WebViewSceneDelegateTests: XCTestCase {
    private var sut: WebViewSceneDelegate!
    private var mockWindowController: MockWebViewWindowControllerForSceneDelegate!
    private var originalRefreshSetting: Bool!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Save original setting value
        originalRefreshSetting = Current.settingsStore.refreshWebViewAfterInactive
        sut = WebViewSceneDelegate()
        mockWindowController = MockWebViewWindowControllerForSceneDelegate()
        sut.windowController = mockWindowController
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        // Restore original setting to prevent test pollution
        Current.settingsStore.refreshWebViewAfterInactive = originalRefreshSetting
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
        XCTAssertNotNil(sut.backgroundTimestamp)
        XCTAssertGreaterThanOrEqual(sut.backgroundTimestamp ?? Date.distantPast, beforeTimestamp)
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
        sut.backgroundTimestamp = oneMinuteAgo

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

        // Ensure setting is enabled (default is ON)
        Current.settingsStore.refreshWebViewAfterInactive = true
        
        // Set background timestamp to 6 minutes ago
        let sixMinutesAgo = Date().addingTimeInterval(-360)
        sut.backgroundTimestamp = sixMinutesAgo

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

    func testSceneDidBecomeActiveWithSettingDisabledDoesNotRefresh() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Disable the setting
        Current.settingsStore.refreshWebViewAfterInactive = false
        
        // Set background timestamp to 6 minutes ago
        let sixMinutesAgo = Date().addingTimeInterval(-360)
        sut.backgroundTimestamp = sixMinutesAgo

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait for async operation
        let expectation = self.expectation(description: "Wait for potential refresh")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertFalse(mockWindowController.mockWebViewController.refreshCalled)
    }

    func testSceneDidBecomeActiveClearsBackgroundTimestamp() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Ensure setting is enabled to test full refresh code path
        Current.settingsStore.refreshWebViewAfterInactive = true
        
        // Set background timestamp to 6 minutes ago (more than 5 to ensure it would trigger refresh)
        let sixMinutesAgo = Date().addingTimeInterval(-360)
        sut.backgroundTimestamp = sixMinutesAgo

        // When
        sut.sceneDidBecomeActive(firstScene)

        // Wait briefly to ensure timestamp is cleared
        let expectation = self.expectation(description: "Wait for timestamp clear")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        // Then
        XCTAssertNil(sut.backgroundTimestamp)
    }

    func testSceneDidBecomeActiveWithExactly5MinutesTriggersRefresh() {
        // Given
        guard let firstScene = UIApplication.shared.connectedScenes.first else {
            XCTFail("No connected scene available")
            return
        }

        // Ensure setting is enabled
        Current.settingsStore.refreshWebViewAfterInactive = true
        
        // Set background timestamp to exactly 5 minutes ago (boundary condition)
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        sut.backgroundTimestamp = fiveMinutesAgo

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
