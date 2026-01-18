@testable import HomeAssistant
import Shared
import XCTest

final class WebViewControllerPullToRefreshTests: XCTestCase {
    private var sut: WebViewController!
    private var mockWebsiteDataStoreHandler: MockWebsiteDataStoreHandler!
    private var originalWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol!
    private var originalDateProvider: @Sendable () -> Date!

    override func setUp() async throws {
        try await super.setUp()

        // Save original handlers
        originalWebsiteDataStoreHandler = Current.websiteDataStoreHandler
        originalDateProvider = Current.date

        // Setup test environment
        mockWebsiteDataStoreHandler = MockWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = mockWebsiteDataStoreHandler

        // Create a test server
        let server = ServerFixture.standard
        sut = WebViewController(server: server, shouldLoadImmediately: false)
    }

    override func tearDown() async throws {
        sut = nil
        mockWebsiteDataStoreHandler = nil

        // Restore original handlers
        Current.websiteDataStoreHandler = originalWebsiteDataStoreHandler
        Current.date = originalDateProvider

        try await super.tearDown()
    }

    func testPullToRefreshFirstTimeDoesNotResetCache() throws {
        // Given: Fresh WebViewController with no previous pull-to-refresh
        let refreshControl = UIRefreshControl()

        // When: Pull-to-refresh is triggered
        sut.pullToRefresh(refreshControl)

        // Then: Cache should NOT be reset on first pull
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)
    }

    func testPullToRefreshTwiceWithin10SecondsResetsCache() throws {
        // Given: A pull-to-refresh action has already occurred
        let refreshControl = UIRefreshControl()

        // When: First pull-to-refresh
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // And: Second pull-to-refresh within 10 seconds
        sut.pullToRefresh(refreshControl)

        // Then: Cache should be reset
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)
    }

    func testPullToRefreshTwiceAfter10SecondsDoesNotResetCache() throws {
        // Given: A pull-to-refresh action occurred more than 10 seconds ago
        let refreshControl = UIRefreshControl()

        // Create a custom date provider that advances time
        var currentDate = Date()
        Current.date = { currentDate }

        // When: First pull-to-refresh
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // And: Move time forward by 11 seconds
        currentDate = currentDate.addingTimeInterval(11)

        // And: Second pull-to-refresh after 10 seconds
        sut.pullToRefresh(refreshControl)

        // Then: Cache should NOT be reset (treated as new first pull)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)
    }

    func testPullToRefreshThreeTimesOnlyResetsCacheOnSecondPull() throws {
        // Given: Multiple pull-to-refresh actions with time control
        let refreshControl = UIRefreshControl()

        // Create a custom date provider that we can control
        var currentDate = Date()
        Current.date = { currentDate }

        // When: First pull-to-refresh
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // And: Advance time by 5 seconds and perform second pull (within 10 seconds - should reset cache)
        currentDate = currentDate.addingTimeInterval(5)
        sut.pullToRefresh(refreshControl)
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // Reset the mock
        mockWebsiteDataStoreHandler.cleanCacheCalled = false

        // And: Advance time by another 5 seconds and perform third pull (within 10 seconds from second pull)
        currentDate = currentDate.addingTimeInterval(5)
        sut.pullToRefresh(refreshControl)

        // Then: Cache should be reset again since it's within 10 seconds of the second pull
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)
    }

    func testPullToRefreshFourTimesAlternatesResetPattern() throws {
        // Given: Multiple pull-to-refresh actions with time control
        let refreshControl = UIRefreshControl()

        // Create a custom date provider that we can control
        var currentDate = Date()
        Current.date = { currentDate }

        // When: First pull-to-refresh
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // And: Second pull within 10 seconds (should reset cache)
        currentDate = currentDate.addingTimeInterval(5)
        sut.pullToRefresh(refreshControl)
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // Reset the mock
        mockWebsiteDataStoreHandler.cleanCacheCalled = false

        // And: Move time forward by 11 seconds (outside 10-second window)
        currentDate = currentDate.addingTimeInterval(11)

        // And: Third pull after 10 seconds (treated as new first pull)
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)

        // And: Fourth pull within 10 seconds (should reset cache again)
        currentDate = currentDate.addingTimeInterval(5)
        sut.pullToRefresh(refreshControl)
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)
    }
}

// MARK: - Mock WebsiteDataStoreHandler

final class MockWebsiteDataStoreHandler: WebsiteDataStoreHandlerProtocol {
    var cleanCacheCalled = false
    var cleanCacheCompletion: (() -> Void)?

    func cleanCache(completion: (() -> Void)?) {
        cleanCacheCalled = true
        cleanCacheCompletion = completion
        completion?()
    }
}
