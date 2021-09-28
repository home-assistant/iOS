import PromiseKit
@testable import Shared
import XCTest

struct TestObject1: Codable, Equatable {
    var uuid1 = UUID()
}

struct TestObject2: Codable, Equatable {
    var uuid2 = UUID()
}

struct DoubleObject1: Codable, Equatable {
    var value: Double
}

class DiskCacheTests: XCTestCase {
    var cache: DiskCacheImpl!

    override func setUp() {
        super.setUp()
        cache = DiskCacheImpl(containerName: "UnitTests_\(UUID().uuidString)")
    }

    func testReadNothing() {
        XCTAssertThrowsError(try hang(cache.value(for: "missing_value")) as TestObject1)
        XCTAssertThrowsError(try hang(cache.value(for: "missing_value2")) as TestObject2)
        XCTAssertThrowsError(try hang(cache.value(for: "missing_value2")) as TestObject1)
    }

    func testReadAfterWrite() {
        let obj1 = TestObject1()
        let obj2 = TestObject1()
        let obj3 = TestObject1()

        let cache: DiskCache = cache
        let key = "key"

        let write1 = cache.set(obj1, for: key)
        let read1 = write1.then { cache.value(for: key) as Promise<TestObject1> }
        let write2 = read1.then { _ in cache.set(obj2, for: key) }
        let read2 = write2.then { cache.value(for: key) as Promise<TestObject1> }
        let write3 = read2.then { _ in cache.set(obj3, for: key) }
        let read3 = write3.then { cache.value(for: key) as Promise<TestObject1> }

        XCTAssertNoThrow(try hang(write1))
        XCTAssertEqual(try hang(read1), obj1)

        XCTAssertNoThrow(try hang(write2))
        XCTAssertEqual(try hang(read2), obj2)

        XCTAssertNoThrow(try hang(write3))
        XCTAssertEqual(try hang(read3), obj3)
    }

    func testInterleaveObjectType() {
        let obj1 = TestObject1()
        let obj2 = TestObject2()
        let obj3 = TestObject1()

        let cache: DiskCache = cache
        let key = "key"

        let write1 = cache.set(obj1, for: key)
        let read1 = write1.then { cache.value(for: key) as Promise<TestObject1> }
        let write2 = read1.then { _ in cache.set(obj2, for: key) }
        let read2a = write2.then { cache.value(for: key) as Promise<TestObject1> }
        let read2b = when(resolved: read2a).then { _ in cache.value(for: key) as Promise<TestObject2> }
        let write3 = read2b.then { _ in cache.set(obj3, for: key) }
        let read3 = write3.then { cache.value(for: key) as Promise<TestObject1> }

        XCTAssertNoThrow(try hang(write1))
        XCTAssertEqual(try hang(read1), obj1)

        XCTAssertNoThrow(try hang(write2))
        XCTAssertThrowsError(try hang(read2a))
        XCTAssertEqual(try hang(read2b), obj2)

        XCTAssertNoThrow(try hang(write3))
        XCTAssertEqual(try hang(read3), obj3)
    }

    func testMultipleKeys() {
        let obj1 = TestObject1()
        let obj2 = TestObject2()
        let obj3 = TestObject1()
        let obj4 = TestObject2()

        let cache: DiskCache = cache

        let write1 = cache.set(obj1, for: "obj1")
        let write2 = cache.set(obj2, for: "obj2")
        let write3 = cache.set(obj3, for: "obj3")
        let write4 = cache.set(obj4, for: "obj4")

        let read1 = write1.then { cache.value(for: "obj1") as Promise<TestObject1> }
        let read2 = write2.then { cache.value(for: "obj2") as Promise<TestObject2> }
        let read3 = write3.then { cache.value(for: "obj3") as Promise<TestObject1> }
        let read4 = write4.then { cache.value(for: "obj4") as Promise<TestObject2> }

        XCTAssertEqual(try hang(read1), obj1)
        XCTAssertEqual(try hang(read2), obj2)
        XCTAssertEqual(try hang(read3), obj3)
        XCTAssertEqual(try hang(read4), obj4)
    }

    func testJsonEncoderFail() {
        let obj1 = DoubleObject1(value: 3)
        let obj2 = DoubleObject1(value: .infinity)

        let cache: DiskCache = cache

        let write1 = cache.set(obj1, for: "obj1/")
        let read1 = write1.then { cache.value(for: "obj1/") as Promise<DoubleObject1> }

        let write2 = cache.set(obj2, for: "obj2")
        let read2 = when(resolved: write2).then { _ in cache.value(for: "obj2") as Promise<DoubleObject1> }

        XCTAssertEqual(try hang(read1), obj1)
        XCTAssertThrowsError(try hang(write2))
        XCTAssertThrowsError(try hang(read2))
    }

    func testInvalidFileNameKey() {
        let obj1 = TestObject1()
        let cache: DiskCache = cache

        let write1 = cache.set(obj1, for: "a//")
        let read1 = write1.then { cache.value(for: "a//") as Promise<TestObject1> }
        XCTAssertEqual(try hang(read1), obj1)
    }

    func testWriteFailure() {
        let obj1 = TestObject1()

        cache.container = URL(fileURLWithPath: "/dev/null")

        let write1 = cache.set(obj1, for: "key")
        XCTAssertThrowsError(try hang(write1))
    }

    func testCoordinatorError() {
        let obj1 = TestObject1()

        let cache: DiskCacheImpl = cache

        // uses a fake coordinator because presenters do not work in the simulator
        cache.coordinator = FailingNSFileCoordinator()

        let write1 = cache.set(obj1, for: "key")
        let read1 = when(resolved: write1).then { _ in cache.value(for: "key") as Promise<TestObject1> }

        XCTAssertThrowsError(try hang(write1))
        XCTAssertThrowsError(try hang(read1))
    }
}

class FailingNSFileCoordinator: NSFileCoordinator {
    enum TestError: Error {
        case any
    }

    init() {
        super.init(filePresenter: nil)
    }

    override func coordinate(
        readingItemAt url: URL,
        options: NSFileCoordinator.ReadingOptions = [],
        error outError: NSErrorPointer,
        byAccessor reader: (URL) -> Void
    ) {
        outError?.pointee = TestError.any as NSError
    }

    override func coordinate(
        writingItemAt url: URL,
        options: NSFileCoordinator.WritingOptions = [],
        error outError: NSErrorPointer,
        byAccessor writer: (URL) -> Void
    ) {
        outError?.pointee = TestError.any as NSError
    }
}
