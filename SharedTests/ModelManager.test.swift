import Foundation
@testable import Shared
import RealmSwift
import XCTest
import PromiseKit

// swiftlint:disable function_body_length

class ModelManagerTests: XCTestCase {
    var realm: Realm!
    var testQueue: DispatchQueue!
    var manager: ModelManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testQueue = DispatchQueue(label: #file)
        manager = ModelManager()

        let executionIdentifier = UUID().uuidString
        try testQueue.sync {
            realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier), queue: testQueue)
            Current.realm = { self.realm }
        }
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
    }

    func testCleanupWithoutItems() {
        let promise = manager.cleanup(definitions: [])
        XCTAssertNoThrow(try hang(promise))
    }

    func testNoneToCleanUp() throws {
        let now = Date()
        Current.date = { now }

        let models = [
            TestDeleteModel1(now.addingTimeInterval(-1)),
            TestDeleteModel1(now.addingTimeInterval(-2)),
            TestDeleteModel1(now.addingTimeInterval(-3))
        ]

        try testQueue.sync {
            try realm.write {
                realm.add(models)
            }
        }

        XCTAssertTrue(models.allSatisfy { $0.realm != nil })

        let promise = manager.cleanup(
            definitions: [
                .init(
                    model: TestDeleteModel1.self,
                    createdKey: #keyPath(TestDeleteModel1.createdAt),
                    duration: .init(value: 100, unit: .seconds)
                )
            ],
            on: testQueue
        )

        XCTAssertNoThrow(try hang(promise))
        XCTAssertTrue(models.allSatisfy { !$0.isInvalidated })
    }

    func testCleanupRemovesOnlyOlder() throws {
        let now = Date()

        let deletedTimeInterval1: TimeInterval = 100
        let deletedTimeInterval2: TimeInterval = 1000

        let deletedLimit1 = Date(timeIntervalSinceNow: -deletedTimeInterval1)
        let deletedLimit2 = Date(timeIntervalSinceNow: -deletedTimeInterval2)

        Current.date = { now }

        let (expectedExpired, expectedAlive) = try testQueue.sync { () -> (expired: [Object], alive: [Object]) in
            let expired = [
                TestDeleteModel1(deletedLimit1.addingTimeInterval(-1)),
                TestDeleteModel1(deletedLimit1.addingTimeInterval(-100)),
                TestDeleteModel1(deletedLimit1.addingTimeInterval(-1000)),
                TestDeleteModel2(deletedLimit2.addingTimeInterval(-1)),
                TestDeleteModel2(deletedLimit2.addingTimeInterval(-100)),
                TestDeleteModel2(deletedLimit2.addingTimeInterval(-1000))
            ]

            let alive = [
                // shouldn't be deleted due to time
                TestDeleteModel1(deletedLimit1),
                TestDeleteModel1(deletedLimit1.addingTimeInterval(10)),
                TestDeleteModel1(deletedLimit1.addingTimeInterval(100)),
                TestDeleteModel2(deletedLimit2),
                TestDeleteModel2(deletedLimit2.addingTimeInterval(10)),
                TestDeleteModel2(deletedLimit2.addingTimeInterval(100)),
                // shouldn't be deleted due to not being requested
                TestDeleteModel3(now.addingTimeInterval(-10000))
            ]

            try realm.write {
                realm.add(expired)
                realm.add(alive)
            }

            return (expired, alive)
        }

        XCTAssertTrue(expectedExpired.allSatisfy { $0.realm != nil })
        XCTAssertTrue(expectedAlive.allSatisfy { $0.realm != nil })

        let promise = manager.cleanup(
            definitions: [
                .init(
                    model: TestDeleteModel1.self,
                    createdKey: #keyPath(TestDeleteModel1.createdAt),
                    duration: .init(value: deletedTimeInterval1, unit: .seconds)
                ),
                .init(
                    model: TestDeleteModel2.self,
                    createdKey: #keyPath(TestDeleteModel2.createdAt),
                    duration: .init(value: deletedTimeInterval2, unit: .seconds)
                )
            ],
            on: testQueue
        )

        XCTAssertNoThrow(try hang(promise))
        XCTAssertTrue(expectedExpired.allSatisfy { $0.isInvalidated })
        XCTAssertTrue(expectedAlive.allSatisfy { !$0.isInvalidated })
    }
}

class TestDeleteModel1: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var createdAt: Date

    init(_ createdAt: Date) {
        self.createdAt = createdAt
    }

    required init() {
        self.createdAt = Date()
    }

    override class func primaryKey() -> String? {
        return #keyPath(TestDeleteModel1.identifier)
    }
}

class TestDeleteModel2: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var createdAt: Date

    init(_ createdAt: Date) {
        self.createdAt = createdAt
    }

    required init() {
        self.createdAt = Date()
    }

    override class func primaryKey() -> String? {
        return #keyPath(TestDeleteModel2.identifier)
    }
}

class TestDeleteModel3: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var createdAt: Date

    init(_ createdAt: Date) {
        self.createdAt = createdAt
    }

    required init() {
        self.createdAt = Date()
    }

    override class func primaryKey() -> String? {
        return #keyPath(TestDeleteModel3.identifier)
    }
}
