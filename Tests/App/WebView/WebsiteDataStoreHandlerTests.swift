@testable import HomeAssistant
@testable import Shared
import WebKit
import XCTest

@MainActor
final class WebsiteDataStoreHandlerTests: XCTestCase {
    private enum Keys {
        static let lastCleanDate = "lastFrontendAssetCacheCleanDate"
        static let lastCleanVersion = "lastFrontendAssetCacheCleanVersion"
    }

    private var previousClientVersion: (() -> Version)!
    private var previousCleanDate: Any?
    private var previousCleanVersion: String?

    override func setUp() {
        super.setUp()
        previousClientVersion = Current.clientVersion
        previousCleanDate = Current.settingsStore.prefs.object(forKey: Keys.lastCleanDate)
        previousCleanVersion = Current.settingsStore.prefs.string(forKey: Keys.lastCleanVersion)
        Current.settingsStore.prefs.removeObject(forKey: Keys.lastCleanDate)
        Current.settingsStore.prefs.removeObject(forKey: Keys.lastCleanVersion)
    }

    override func tearDown() {
        Current.clientVersion = previousClientVersion
        Current.settingsStore.prefs.set(previousCleanDate, forKey: Keys.lastCleanDate)
        Current.settingsStore.prefs.set(previousCleanVersion, forKey: Keys.lastCleanVersion)
        super.tearDown()
    }

    /// The store answers at once, so the tests exercise the handler's own bookkeeping rather than how
    /// long WebKit takes to clear a data store on the machine running them.
    private func makeSUT() -> WebsiteDataStoreHandler {
        WebsiteDataStoreHandler(removeData: { _, completion in completion() })
    }

    func testCleaningTheFrontendAssetCacheRecordsTheVersionThatCleanedIt() async {
        Current.clientVersion = { Version(major: 2026, minor: 9, patch: 3) }
        let sut = makeSUT()
        let cleaned = expectation(description: "frontend asset cache cleaned")

        sut.cleanFrontendAssetCacheIfNeeded { didClean in
            XCTAssertTrue(didClean)
            cleaned.fulfill()
        }

        await fulfillment(of: [cleaned], timeout: 10)
        XCTAssertEqual(Current.settingsStore.prefs.string(forKey: Keys.lastCleanVersion), "2026.9.3")
    }

    func testTheFrontendAssetCacheIsCleanedAgainAfterAnAppUpdate() async {
        Current.clientVersion = { Version(major: 2026, minor: 9, patch: 3) }
        let sut = makeSUT()
        let cleaned = expectation(description: "frontend asset cache cleaned")
        sut.cleanFrontendAssetCacheIfNeeded { _ in cleaned.fulfill() }
        await fulfillment(of: [cleaned], timeout: 10)

        let skipped = expectation(description: "clean skipped for the same version")
        sut.cleanFrontendAssetCacheIfNeeded { didClean in
            XCTAssertFalse(didClean)
            skipped.fulfill()
        }
        await fulfillment(of: [skipped], timeout: 10)

        Current.clientVersion = { Version(major: 2026, minor: 9, patch: 4) }
        let cleanedAfterUpdate = expectation(description: "frontend asset cache cleaned after the update")
        sut.cleanFrontendAssetCacheIfNeeded { didClean in
            XCTAssertTrue(didClean)
            cleanedAfterUpdate.fulfill()
        }

        await fulfillment(of: [cleanedAfterUpdate], timeout: 10)
        XCTAssertEqual(Current.settingsStore.prefs.string(forKey: Keys.lastCleanVersion), "2026.9.4")
    }
}
