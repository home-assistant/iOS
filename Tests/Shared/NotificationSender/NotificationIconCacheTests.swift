@testable import Shared
import XCTest

final class NotificationIconCacheTests: XCTestCase {
    private var cache: NotificationIconCacheImpl!
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("NotificationIconCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        cache = NotificationIconCacheImpl(directory: tempDir, maxEntries: 3)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testMissReturnsNil() {
        XCTAssertNil(cache.data(forKey: "missing"))
    }

    func testWriteThenRead_roundTrips() {
        let payload = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic
        cache.setData(payload, forKey: "abc")
        XCTAssertEqual(cache.data(forKey: "abc"), payload)
    }

    func testEviction_dropsOldestWhenOverLimit() {
        cache.setData(Data([1]), forKey: "k1")
        Thread.sleep(forTimeInterval: 0.01) // ensure distinct mtimes
        cache.setData(Data([2]), forKey: "k2")
        Thread.sleep(forTimeInterval: 0.01)
        cache.setData(Data([3]), forKey: "k3")
        Thread.sleep(forTimeInterval: 0.01)
        cache.setData(Data([4]), forKey: "k4") // triggers eviction; max is 3

        XCTAssertNil(cache.data(forKey: "k1"), "k1 should be evicted")
        XCTAssertEqual(cache.data(forKey: "k4"), Data([4]))
    }

    func testKeyHashing_returnsSameKeyForSameURL() throws {
        let key1 = try notificationIconCacheKey(for: XCTUnwrap(URL(string: "https://example.com/a.png")))
        let key2 = try notificationIconCacheKey(for: XCTUnwrap(URL(string: "https://example.com/a.png")))
        XCTAssertEqual(key1, key2)
    }

    func testKeyHashing_returnsDifferentKeysForDifferentURLs() throws {
        let k1 = try notificationIconCacheKey(for: XCTUnwrap(URL(string: "https://example.com/a.png")))
        let k2 = try notificationIconCacheKey(for: XCTUnwrap(URL(string: "https://example.com/b.png")))
        XCTAssertNotEqual(k1, k2)
    }
}
