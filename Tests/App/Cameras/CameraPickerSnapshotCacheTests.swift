@testable import HomeAssistant
import Shared
import UIKit
import XCTest

/// The picker asks the server for a still of every camera each time the player opens. A camera the
/// server cannot produce an image for answered every one of those requests with a 500, so the cache
/// remembers the failure and stops asking for a while instead of retrying on every open.
@MainActor
final class CameraPickerSnapshotCacheTests: XCTestCase {
    private let key = CameraPickerSnapshotCache.Key(serverId: "server", entityId: "camera.front_door")
    private var now = Date(timeIntervalSince1970: 1_000_000)

    override func setUp() {
        super.setUp()
        Current.date = { [weak self] in self?.now ?? Date() }
    }

    override func tearDown() {
        Current.date = Date.init
        super.tearDown()
    }

    func testAnUnknownCameraIsFetched() {
        let cache = CameraPickerSnapshotCache(failureRetryInterval: 300)

        XCTAssertTrue(cache.shouldFetch(key))
        XCTAssertNil(cache.image(for: key))
    }

    func testAStoredImageIsReturnedAndNotFetchedAgain() {
        let cache = CameraPickerSnapshotCache(failureRetryInterval: 300)

        cache.store(UIImage(), for: key)

        XCTAssertNotNil(cache.image(for: key))
        XCTAssertFalse(cache.shouldFetch(key))
    }

    func testARecentFailureSuppressesTheFetchUntilTheIntervalPasses() {
        let cache = CameraPickerSnapshotCache(failureRetryInterval: 300)

        cache.recordFailure(for: key)
        XCTAssertFalse(cache.shouldFetch(key))

        now = now.addingTimeInterval(299)
        XCTAssertFalse(cache.shouldFetch(key))

        now = now.addingTimeInterval(1)
        XCTAssertTrue(cache.shouldFetch(key))
    }

    func testASuccessClearsAnEarlierFailure() {
        let cache = CameraPickerSnapshotCache(failureRetryInterval: 300)

        cache.recordFailure(for: key)
        cache.store(UIImage(), for: key)

        XCTAssertNotNil(cache.image(for: key))
    }
}
