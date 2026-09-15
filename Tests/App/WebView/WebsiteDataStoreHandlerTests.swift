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

    /// The real store is left out of these: its completion comes back through the WebKit
    /// networking process, which does not reliably start under the test runner.
    private func handler(recordingInto removed: RemovedTypes = RemovedTypes()) -> WebsiteDataStoreHandler {
        WebsiteDataStoreHandler { dataTypes, _, completion in
            removed.dataTypes.append(dataTypes)
            completion()
        }
    }

    private final class RemovedTypes {
        var dataTypes: [Set<String>] = []
    }

    func testCleaningTheFrontendAssetCacheRecordsTheVersionThatCleanedIt() async {
        Current.clientVersion = { Version(major: 2026, minor: 9, patch: 3) }
        let removed = RemovedTypes()
        let sut = handler(recordingInto: removed)
        let cleaned = expectation(description: "frontend asset cache cleaned")

        sut.cleanFrontendAssetCacheIfNeeded { didClean in
            XCTAssertTrue(didClean)
            cleaned.fulfill()
        }

        await fulfillment(of: [cleaned], timeout: 10)
        XCTAssertEqual(Current.settingsStore.prefs.string(forKey: Keys.lastCleanVersion), "2026.9.3")
        XCTAssertEqual(removed.dataTypes, [WebsiteDataStoreHandlerImpl.frontendAssetDataTypes])
    }

    func testTheFrontendAssetCacheIsCleanedAgainAfterAnAppUpdate() async {
        Current.clientVersion = { Version(major: 2026, minor: 9, patch: 3) }
        let removed = RemovedTypes()
        let sut = handler(recordingInto: removed)
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
        // Twice, not three times: the middle call was skipped for the same version.
        XCTAssertEqual(removed.dataTypes.count, 2)
    }
}
