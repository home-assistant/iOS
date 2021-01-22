import Foundation
@testable import Shared
import RealmSwift
import XCTest
import PromiseKit

// swiftlint:disable function_body_length

class ModelManagerTests: XCTestCase {
    private var realm: Realm!
    private var testQueue: DispatchQueue!
    private var manager: ModelManager!
    private var api: FakeHomeAssistantAPI!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testQueue = DispatchQueue(label: #file)
        manager = ModelManager()
        api = FakeHomeAssistantAPI(
            tokenInfo: .init(
                accessToken: "atoken",
                refreshToken: "refreshtoken",
                expiration: Date()
            )
        )

        Current.api = .value(api)

        let executionIdentifier = UUID().uuidString
        try testQueue.sync {
            realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier), queue: testQueue)
            Current.realm = { self.realm }
        }
    }

    override func tearDown() {
        super.tearDown()

        Current.resetAPI()
        Current.realm = Realm.live
        TestStoreModel1.lastDidUpdate = []
        TestStoreModel1.lastWillDeleteIds = []
    }

    func testObserve() throws {
        try testQueue.sync {
            let results = AnyRealmCollection(realm.objects(TestStoreModel1.self))

            let executedExpectation = self.expectation(description: "observed")
            executedExpectation.expectedFulfillmentCount = 2

            var didObserveCount = 0

            manager.observe(for: results) { collection -> Promise<Void> in
                XCTAssertEqual(Array(collection), Array(results))
                didObserveCount += 1
                executedExpectation.fulfill()
                return .value(())
            }

            realm.refresh()

            XCTAssertEqual(didObserveCount, 0)

            try realm.write {
                realm.add(with(TestStoreModel1()) {
                    $0.identifier = "123"
                    $0.value = "456"
                })
            }

            realm.refresh()

            XCTAssertEqual(didObserveCount, 1)

            try realm.write {
                realm.add(with(TestStoreModel1()) {
                    $0.identifier = "qrs"
                    $0.value = "tuv"
                })
            }

            realm.refresh()

            XCTAssertEqual(didObserveCount, 2)

            wait(for: [executedExpectation], timeout: 10.0)
        }
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

    func testFetchInvokesDefinition() {
        let (fetchPromise1, fetchSeal1) = Promise<Void>.pending()
        let (fetchPromise2, fetchSeal2) = Promise<Void>.pending()

        let promise = manager.fetch(definitions: [
            .init(update: { api, queue, manager -> Promise<Void> in
                XCTAssertTrue(api === self.api)
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                return fetchPromise1
            }),
            .init(update: { api, queue, manager -> Promise<Void> in
                XCTAssertTrue(api === self.api)
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                return fetchPromise2
            }),
        ], on: testQueue)

        XCTAssertFalse(promise.isResolved)
        fetchSeal1.fulfill(())
        XCTAssertFalse(promise.isResolved)
        fetchSeal2.fulfill(())
        XCTAssertNoThrow(try hang(promise))
    }

    func testStoreWithoutModels() throws {
        try testQueue.sync {
            try manager.store(type: TestStoreModel1.self, sourceModels: [])
            XCTAssertTrue(realm.objects(TestStoreModel1.self).isEmpty)
        }
    }

    func testStoreWithModelLackingPrimaryKey() throws {
        func doStore() throws {
            try testQueue.sync {
                try manager.store(type: TestStoreModel2.self, sourceModels: [])
            }
        }

        XCTAssertThrowsError(try doStore()) { error in
            XCTAssertEqual(error as? ModelManager.StoreError, .missingPrimaryKey)
        }
    }

    func testStoreWithoutExistingObjects() throws {
        try testQueue.sync {
            let sources: [TestStoreSource1] = [
                .init(id: "id1", value: "val1"),
                .init(id: "id2", value: "val2")
            ]

            try manager.store(type: TestStoreModel1.self, sourceModels: sources)
            let models = realm.objects(TestStoreModel1.self).sorted(byKeyPath: #keyPath(TestStoreModel1.identifier))
            XCTAssertEqual(models.count, 2)
            XCTAssertEqual(models[0].identifier, "id1")
            XCTAssertEqual(models[0].value, "val1")
            XCTAssertEqual(models[1].identifier, "id2")
            XCTAssertEqual(models[1].value, "val2")
            XCTAssertEqual(Set(TestStoreModel1.lastDidUpdate), Set(models))
        }
    }

    func testStoreUpdatesAndDeletes() throws {
        let start = [
            with(TestStoreModel1()) {
                $0.identifier = "start_id1"
                $0.value = "start_val1"
            },
            with(TestStoreModel1()) {
                $0.identifier = "start_id2"
                $0.value = "start_val2"
            },
            with(TestStoreModel1()) {
                $0.identifier = "start_id3"
                $0.value = "start_val3"
            },
            with(TestStoreModel1()) {
                $0.identifier = "start_id4"
                $0.value = "start_val4"
            }
        ]

        let insertedSources = [
            TestStoreSource1(id: "ins_id1", value: "ins_val1"),
            TestStoreSource1(id: "ins_id2", value: "ins_val2")
        ]

        let updatedSources = [
            TestStoreSource1(id: "start_id1", value: "start_val1-2"),
            TestStoreSource1(id: "start_id2", value: "start_val2-2")
        ]

        try testQueue.sync {
            try realm.write {
                realm.add(start)
            }

            try manager.store(type: TestStoreModel1.self, sourceModels: insertedSources + updatedSources)
            let models = realm.objects(TestStoreModel1.self).sorted(byKeyPath: #keyPath(TestStoreModel1.identifier))
            XCTAssertEqual(models.count, 4)

            // inserted
            XCTAssertEqual(models[0].identifier, "ins_id1")
            XCTAssertEqual(models[0].value, "ins_val1")
            XCTAssertEqual(models[1].identifier, "ins_id2")
            XCTAssertEqual(models[1].value, "ins_val2")

            // updated
            XCTAssertEqual(models[2].identifier, "start_id1")
            XCTAssertEqual(models[2].value, "start_val1-2")
            XCTAssertEqual(models[3].identifier, "start_id2")
            XCTAssertEqual(models[3].value, "start_val2-2")

            // deleted
            XCTAssertEqual(Set(TestStoreModel1.lastWillDeleteIds), Set([
                "start_id3",
                "start_id4",
            ]))
        }
    }

    func testIneligibleNotDeleted() throws {
        let start = [
            with(TestStoreModel3()) {
                $0.identifier = "start_id1"
                $0.value = 10 // eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "start_id2"
                $0.value = 1 // not eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "start_id3"
                $0.value = 100 // eligible, will be deleted
            },
        ]

        let insertedSources = [
            TestStoreSource2(id: "ins_id1", value: 100),
        ]

        let updatedSources = [
            TestStoreSource2(id: "start_id1", value: 4),
        ]

        try testQueue.sync {
            try realm.write {
                realm.add(start)
            }

            try manager.store(type: TestStoreModel3.self, sourceModels: insertedSources + updatedSources)
            let models = realm.objects(TestStoreModel3.self).sorted(byKeyPath: #keyPath(TestStoreModel3.value))
            XCTAssertEqual(models.count, 3)

            XCTAssertEqual(models[0].identifier, "start_id2")
            XCTAssertEqual(models[0].value, 1)
            XCTAssertEqual(models[1].identifier, "start_id1")
            XCTAssertEqual(models[1].value, 4)
            XCTAssertEqual(models[2].identifier, "ins_id1")
            XCTAssertEqual(models[2].value, 100)
        }

    }
}

class TestDeleteModel1: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var createdAt: Date

    init(_ createdAt: Date) {
        self.createdAt = createdAt
    }

    required override init() {
        self.createdAt = Date()
        super.init()
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

    override required init() {
        self.createdAt = Date()
        super.init()
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
        super.init()
    }

    required override init() {
        self.createdAt = Date()
        super.init()
    }

    override class func primaryKey() -> String? {
        return #keyPath(TestDeleteModel3.identifier)
    }
}

final class TestStoreModel1: Object, UpdatableModel {
    static var lastDidUpdate: [TestStoreModel1] = []
    static var lastWillDeleteIds: [String] = []
    static func didUpdate(objects: [TestStoreModel1], realm: Realm) {
        lastDidUpdate = objects
    }
    static func willDelete(objects: [TestStoreModel1], realm: Realm) {
        lastWillDeleteIds = objects.compactMap(\.identifier)
    }

    @objc dynamic var identifier: String?
    @objc dynamic var value: String?

    override class func primaryKey() -> String? {
        #keyPath(TestStoreModel1.identifier)
    }

    func update(
        with object: TestStoreSource1,
        using realm: Realm
    ) {
        if self.realm == nil {
            identifier = object.id
        } else {
            XCTAssertEqual(identifier, object.id)
        }
        value = object.value
    }
}

struct TestStoreSource1: UpdatableModelSource {
    var primaryKey: String { id }

    var id: String = UUID().uuidString
    var value: String?
}

final class TestStoreModel2: Object, UpdatableModel {
    static func didUpdate(objects: [TestStoreModel2], realm: Realm) {

    }

    static func willDelete(objects: [TestStoreModel2], realm: Realm) {

    }

    @objc dynamic var identifier: String?

    override class func primaryKey() -> String? {
        nil
    }

    func update(
        with object: TestStoreSource1,
        using realm: Realm
    ) {
        XCTFail("not expected to be called in error scenario")
    }
}

struct TestStoreSource2: UpdatableModelSource {
    var primaryKey: String { id }

    var id: String = UUID().uuidString
    var value: Int = 0
}

final class TestStoreModel3: Object, UpdatableModel {
    static func didUpdate(objects: [TestStoreModel3], realm: Realm) {

    }

    static func willDelete(objects: [TestStoreModel3], realm: Realm) {

    }

    static var updateEligiblePredicate: NSPredicate {
        .init(format: "value > 5")
    }

    @objc dynamic var identifier: String?
    @objc dynamic var value: Int = 0

    override class func primaryKey() -> String? {
        "identifier"
    }

    func update(
        with object: TestStoreSource2,
        using realm: Realm
    ) {
        if self.realm == nil {
            identifier = object.id
        } else {
            XCTAssertEqual(identifier, object.id)
        }
        value = object.value
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {

}
