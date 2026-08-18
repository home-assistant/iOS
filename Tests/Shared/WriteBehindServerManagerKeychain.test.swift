@testable import Shared
import XCTest

class WriteBehindServerManagerKeychainTests: XCTestCase {
    private var upstream: FakeServerManagerKeychain!
    private var queuedFlushes: [() -> Void]!
    private var keychain: WriteBehindServerManagerKeychain!

    override func setUp() {
        super.setUp()

        upstream = FakeServerManagerKeychain()
        queuedFlushes = []
        keychain = WriteBehindServerManagerKeychain(upstream: upstream, flushExecutor: { [weak self] work in
            self?.queuedFlushes.append(work)
        })
    }

    private func runQueuedFlushes() {
        let flushes = queuedFlushes ?? []
        queuedFlushes = []
        for flush in flushes {
            flush()
        }
    }

    func testSetIsVisibleImmediatelyAndFlushedLater() throws {
        let value = Data("server".utf8)

        try keychain.set(value, key: "key1")

        XCTAssertEqual(try keychain.getData("key1"), value)
        XCTAssertEqual(keychain.allKeys(), ["key1"])
        XCTAssertNil(try upstream.getData("key1"))

        runQueuedFlushes()

        XCTAssertEqual(try upstream.getData("key1"), value)
        XCTAssertEqual(try keychain.getData("key1"), value)
    }

    func testRemoveIsVisibleImmediatelyAndFlushedLater() throws {
        try upstream.set(Data("server".utf8), key: "key1")

        try keychain.remove("key1")

        XCTAssertNil(try keychain.getData("key1"))
        XCTAssertTrue(keychain.allKeys().isEmpty)
        XCTAssertNotNil(try upstream.getData("key1"))

        runQueuedFlushes()

        XCTAssertNil(try upstream.getData("key1"))
        XCTAssertNil(try keychain.getData("key1"))
    }

    func testLatestWriteWinsWhenFlushesCoalesce() throws {
        let first = Data("first".utf8)
        let second = Data("second".utf8)

        try keychain.set(first, key: "key1")
        try keychain.set(second, key: "key1")

        XCTAssertEqual(try keychain.getData("key1"), second)

        runQueuedFlushes()

        XCTAssertEqual(try upstream.getData("key1"), second)
        XCTAssertEqual(try keychain.getData("key1"), second)
    }

    func testSetThenRemoveEndsRemoved() throws {
        try keychain.set(Data("server".utf8), key: "key1")
        try keychain.remove("key1")

        XCTAssertNil(try keychain.getData("key1"))

        runQueuedFlushes()

        XCTAssertNil(try upstream.getData("key1"))
        XCTAssertNil(try keychain.getData("key1"))
        XCTAssertTrue(keychain.allKeys().isEmpty)
    }

    func testRemoveAllMasksUpstreamUntilFlushed() throws {
        try upstream.set(Data("one".utf8), key: "key1")
        try upstream.set(Data("two".utf8), key: "key2")

        try keychain.removeAll()

        XCTAssertNil(try keychain.getData("key1"))
        XCTAssertNil(try keychain.getData("key2"))
        XCTAssertTrue(keychain.allKeys().isEmpty)

        // a write after removeAll must survive it
        let replacement = Data("three".utf8)
        try keychain.set(replacement, key: "key3")
        XCTAssertEqual(try keychain.getData("key3"), replacement)
        XCTAssertEqual(keychain.allKeys(), ["key3"])

        runQueuedFlushes()

        XCTAssertEqual(upstream.allKeys(), ["key3"])
        XCTAssertEqual(try keychain.getData("key3"), replacement)
    }

    func testAllKeysMergesPendingWrites() throws {
        try upstream.set(Data("one".utf8), key: "key1")
        try upstream.set(Data("two".utf8), key: "key2")

        try keychain.set(Data("three".utf8), key: "key3")
        try keychain.remove("key2")

        XCTAssertEqual(Set(keychain.allKeys()), Set(["key1", "key3"]))
    }

    func testFailedFlushKeepsPendingWriteAndRetriesOnNextFlush() throws {
        let failingUpstream = FailingSetServerManagerKeychain()
        var queued = [() -> Void]()
        let keychain = WriteBehindServerManagerKeychain(upstream: failingUpstream, flushExecutor: { queued.append($0) })

        let first = Data("first".utf8)
        try keychain.set(first, key: "key1")

        failingUpstream.failSets = true
        let flushes = queued
        queued = []
        flushes.forEach { $0() }

        // the write failed to persist but must stay visible to readers
        XCTAssertEqual(try keychain.getData("key1"), first)
        XCTAssertEqual(keychain.allKeys(), ["key1"])
        XCTAssertNil(try failingUpstream.wrapped.getData("key1"))

        failingUpstream.failSets = false
        let second = Data("second".utf8)
        try keychain.set(second, key: "key1")
        queued.forEach { $0() }

        XCTAssertEqual(try failingUpstream.wrapped.getData("key1"), second)
        XCTAssertEqual(try keychain.getData("key1"), second)
    }

    func testDefaultExecutorFlushesWithoutBlockingCaller() throws {
        let defaultKeychain = WriteBehindServerManagerKeychain(upstream: upstream)
        let value = Data("server".utf8)

        try defaultKeychain.set(value, key: "key1")

        XCTAssertEqual(try defaultKeychain.getData("key1"), value)

        let flushed = expectation(
            for: NSPredicate(block: { [upstream] _, _ in
                (try? upstream?.getData("key1")) == value
            }),
            evaluatedWith: nil
        )
        wait(for: [flushed], timeout: 10)
    }
}

private class FailingSetServerManagerKeychain: ServerManagerKeychain {
    let wrapped = FakeServerManagerKeychain()
    var failSets = false

    struct SetError: Error {}

    func set(_ value: Data, key: String) throws {
        if failSets {
            throw SetError()
        }
        try wrapped.set(value, key: key)
    }

    func removeAll() throws {
        try wrapped.removeAll()
    }

    func allKeys() -> [String] {
        wrapped.allKeys()
    }

    func getData(_ key: String) throws -> Data? {
        try wrapped.getData(key)
    }

    func remove(_ key: String) throws {
        try wrapped.remove(key)
    }
}
