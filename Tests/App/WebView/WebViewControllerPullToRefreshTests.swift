@testable import HomeAssistant
import Shared
import XCTest

final class WebViewControllerPullToRefreshTests: XCTestCase {
    private var sut: WebViewController!
    private var mockWebsiteDataStoreHandler: MockWebsiteDataStoreHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test environment
        mockWebsiteDataStoreHandler = MockWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = mockWebsiteDataStoreHandler
        
        // Create a test server
        let server = ServerFixture.standard
        sut = WebViewController(server: server, shouldLoadImmediately: false)
    }
    
    override func tearDown() {
        sut = nil
        mockWebsiteDataStoreHandler = nil
        super.tearDown()
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
        // Given: Multiple pull-to-refresh actions
        let refreshControl = UIRefreshControl()
        
        // When: First pull-to-refresh
        sut.pullToRefresh(refreshControl)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)
        
        // And: Second pull-to-refresh within 10 seconds (should reset cache)
        sut.pullToRefresh(refreshControl)
        XCTAssertTrue(mockWebsiteDataStoreHandler.cleanCacheCalled)
        
        // Reset the mock
        mockWebsiteDataStoreHandler.cleanCacheCalled = false
        
        // And: Third pull-to-refresh immediately after
        sut.pullToRefresh(refreshControl)
        
        // Then: Cache should NOT be reset again (timestamp was reset after second pull)
        XCTAssertFalse(mockWebsiteDataStoreHandler.cleanCacheCalled)
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
