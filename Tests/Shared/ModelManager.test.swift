import Foundation
import HAKit
import PromiseKit
import RealmSwift
@testable import Shared
import XCTest

class ModelManagerTests: XCTestCase {
    private var realm: Realm!
    private var testQueue: DispatchQueue!
    private var manager: ModelManager!
    private var servers: FakeServerManager!
    private var api1: FakeHomeAssistantAPI!
    private var api2: FakeHomeAssistantAPI!
    private var apiConnection1: HAMockConnection!
    private var apiConnection2: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testQueue = DispatchQueue(label: #file)
        manager = ModelManager()
        manager.workQueue = testQueue

        servers = FakeServerManager(initial: 0)
        let server1 = servers.add(identifier: "s1", serverInfo: .fake())
        let server2 = servers.add(identifier: "s2", serverInfo: .fake())
        api1 = FakeHomeAssistantAPI(server: server1)
        api2 = FakeHomeAssistantAPI(server: server2)
        apiConnection1 = HAMockConnection()
        api1.connection = apiConnection1
        apiConnection2 = HAMockConnection()
        api2.connection = apiConnection2
        Current.servers = servers
        Current.cachedApis = [server1.identifier: api1, server2.identifier: api2]

        let executionIdentifier = UUID().uuidString
        try testQueue.sync {
            realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier), queue: testQueue)
            Current.realm = { self.realm }
        }
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
        TestStoreModel1.lastDidUpdates = []
        TestStoreModel1.lastWillDeleteIds = []
        TestStoreModel1.updateFalseIds = []

        TestStoreModel3.lastWillDeleteIds = []
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
            TestDeleteModel1(now.addingTimeInterval(-3)),
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
                ),
            ]
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
                TestDeleteModel2(deletedLimit2.addingTimeInterval(-1000)),
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
                TestDeleteModel3(now.addingTimeInterval(-10000)),
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
                ),
            ]
        )

        XCTAssertNoThrow(try hang(promise))
        XCTAssertTrue(expectedExpired.allSatisfy(\.isInvalidated))
        XCTAssertTrue(expectedAlive.allSatisfy { !$0.isInvalidated })
    }

    func testCleanupMissingServers() throws {
        let server3 = servers.addFake()
        let api3 = FakeHomeAssistantAPI(server: server3)
        Current.cachedApis[server3.identifier] = api3

        let start1 = [
            with(TestStoreModel1()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m1"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m2"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m3"
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m4"
                $0.value = 1 // not deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m5"
                $0.value = 6 // deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.identifier = "s1m6"
                $0.value = 8 // deleted
            },
        ]
        let start2 = [
            with(TestStoreModel1()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m1"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m2"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m3"
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m4"
                $0.value = 1 // not deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m5"
                $0.value = 6 // deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.identifier = "s2m6"
                $0.value = 8 // deleted
            },
        ]
        let start3 = [
            with(TestStoreModel1()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m1"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m2"
            },
            with(TestStoreModel1()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m3"
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m4"
                $0.value = 1 // not deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m5"
                $0.value = 6 // deleted
            },
            with(TestStoreModel3()) {
                $0.serverIdentifier = api3.server.identifier.rawValue
                $0.identifier = "s3m6"
                $0.value = 8 // deleted
            },
        ]

        manager.cleanup(definitions: [
            .init(orphansOf: TestStoreModel1.self),
            .init(orphansOf: TestStoreModel3.self),
        ]).cauterize()

        try testQueue.sync {
            try realm.write {
                realm.add(start1)
                realm.add(start2)
                realm.add(start3)
            }
        }

        servers.remove(identifier: api2.server.identifier)
        servers.notify()

        try testQueue.sync {
            let expected = Set(start1 + start3 + [start2[3]])
            let present = Set<Object>(realm.objects(TestStoreModel1.self).map { $0 as Object })
                .union(realm.objects(TestStoreModel3.self).map { $0 as Object })
            XCTAssertEqual(present, expected)

            XCTAssertEqual(
                try XCTUnwrap(start2[3] as? TestStoreModel3).serverIdentifier,
                api1.server.identifier.rawValue
            )
        }

        XCTAssertEqual(Set(TestStoreModel1.lastWillDeleteIds.flatMap { $0 }), Set([
            "s2m1", "s2m2", "s2m3",
        ]))
        XCTAssertEqual(Set(TestStoreModel3.lastWillDeleteIds.flatMap { $0 }), Set([
            "s2m5", "s2m6",
        ]))
    }

    func testFetchInvokesDefinition() {
        let (fetchPromise1, fetchSeal1) = Promise<Void>.pending()
        let (fetchPromise2, fetchSeal2) = Promise<Void>.pending()

        var fetchApi1 = [HomeAssistantAPI]()
        var fetchApi2 = [HomeAssistantAPI]()

        let promise = manager.fetch(definitions: [
            .init(update: { api, queue, manager -> Promise<Void> in
                fetchApi1.append(api)
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                return fetchPromise1
            }),
            .init(update: { api, queue, manager -> Promise<Void> in
                fetchApi2.append(api)
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                return fetchPromise2
            }),
        ], apis: [api1, api2])

        XCTAssertFalse(promise.isResolved)
        fetchSeal1.fulfill(())
        XCTAssertFalse(promise.isResolved)
        fetchSeal2.fulfill(())
        XCTAssertNoThrow(try hang(promise))

        XCTAssertEqual(fetchApi1.map(\.server), [api1.server, api2.server])
        XCTAssertEqual(fetchApi2.map(\.server), [api1.server, api2.server])
    }

    func testSubscribeSubscribes() {
        let handlers1_1: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })
        let handlers2_1: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })
        let handlers1_2: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })
        let handlers2_2: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })
        let handlers1_3: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })
        let handlers2_3: [HAMockCancellable] = Array((0 ... 1).map { _ in HAMockCancellable({}) })

        var handlers1Iterator = handlers1_1.makeIterator()
        var handlers2Iterator = handlers2_1.makeIterator()

        var handlers1APIs = [(HAConnection, Server)]()
        var handlers2APIs = [(HAConnection, Server)]()

        let definitions: [ModelManager.SubscribeDefinition] = [
            .init(subscribe: { connection, server, queue, manager -> [HACancellable] in
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                handlers1APIs.append((connection, server))
                return [handlers1Iterator.next()!]
            }),
            .init(subscribe: { connection, server, queue, manager -> [HACancellable] in
                XCTAssertEqual(queue, self.testQueue)
                XCTAssertTrue(manager === self.manager)
                handlers2APIs.append((connection, server))
                return [handlers2Iterator.next()!]
            }),
        ]

        manager.subscribe(definitions: definitions)

        func verify(apis: [HomeAssistantAPI]) {
            XCTAssertEqual(handlers1APIs.map(\.1), apis.map(\.server))
            XCTAssertEqual(handlers2APIs.map(\.1), apis.map(\.server))
            XCTAssertEqual(
                handlers1APIs.map(\.0).map(ObjectIdentifier.init(_:)),
                apis.map(\.connection).map(ObjectIdentifier.init(_:))
            )
        }

        verify(apis: [api1, api2])

        XCTAssertTrue(handlers1_1.allSatisfy { !$0.wasCancelled })
        XCTAssertTrue(handlers2_1.allSatisfy { !$0.wasCancelled })

        handlers1Iterator = handlers1_2.makeIterator()
        handlers2Iterator = handlers2_2.makeIterator()

        handlers1APIs.removeAll()
        handlers2APIs.removeAll()

        manager.subscribe(definitions: definitions)

        XCTAssertTrue(handlers1_1.allSatisfy(\.wasCancelled))
        XCTAssertTrue(handlers2_1.allSatisfy(\.wasCancelled))

        XCTAssertTrue(handlers1_2.allSatisfy { !$0.wasCancelled })
        XCTAssertTrue(handlers2_2.allSatisfy { !$0.wasCancelled })

        verify(apis: [api1, api2])

        servers.remove(identifier: api1.server.identifier)
        let new = servers.addFake()
        let newApi = FakeHomeAssistantAPI(server: new)
        Current.cachedApis[new.identifier] = newApi

        handlers1Iterator = handlers1_3.makeIterator()
        handlers2Iterator = handlers2_3.makeIterator()

        handlers1APIs.removeAll()
        handlers2APIs.removeAll()

        servers.notify()

        XCTAssertTrue(handlers1_2.allSatisfy(\.wasCancelled))
        XCTAssertTrue(handlers2_2.allSatisfy(\.wasCancelled))

        verify(apis: [api2, newApi])
    }

    func testStoreWithoutModels() throws {
        try testQueue.sync {
            try hang(manager.store(type: TestStoreModel1.self, from: api1.server, sourceModels: []))
            XCTAssertTrue(realm.objects(TestStoreModel1.self).isEmpty)
        }
    }

    func testStoreWithModelLackingPrimaryKey() throws {
        func doStore() throws {
            try testQueue.sync {
                try hang(manager.store(type: TestStoreModel2.self, from: api1.server, sourceModels: []))
            }
        }

        XCTAssertThrowsError(try doStore()) { error in
            XCTAssertEqual(error as? ModelManager.StoreError, .missingPrimaryKey)
        }
    }

    func testStoreWithoutExistingObjects() throws {
        try testQueue.sync {
            let sources1: [TestStoreSource1] = [
                .init(id: "id1s1", value: "val1"),
                .init(id: "id2s1", value: "val2"),
            ]
            let sources2: [TestStoreSource1] = [
                .init(id: "id1s2", value: "val1"),
                .init(id: "id2s2", value: "val2"),
            ]

            try hang(manager.store(type: TestStoreModel1.self, from: api1.server, sourceModels: sources1))
            try hang(manager.store(type: TestStoreModel1.self, from: api2.server, sourceModels: sources2))
            let models = realm.objects(TestStoreModel1.self).sorted(byKeyPath: #keyPath(TestStoreModel1.identifier))
            XCTAssertEqual(models.count, 4)
            XCTAssertEqual(models[0].identifier, "s1/id1s1")
            XCTAssertEqual(models[0].serverIdentifier, api1.server.identifier.rawValue)
            XCTAssertEqual(models[0].value, "val1")
            XCTAssertEqual(models[1].identifier, "s1/id2s1")
            XCTAssertEqual(models[1].serverIdentifier, api1.server.identifier.rawValue)
            XCTAssertEqual(models[1].value, "val2")
            XCTAssertEqual(models[2].identifier, "s2/id1s2")
            XCTAssertEqual(models[2].serverIdentifier, api2.server.identifier.rawValue)
            XCTAssertEqual(models[2].value, "val1")
            XCTAssertEqual(models[3].identifier, "s2/id2s2")
            XCTAssertEqual(models[3].serverIdentifier, api2.server.identifier.rawValue)
            XCTAssertEqual(models[3].value, "val2")
            XCTAssertEqual(Set(TestStoreModel1.lastDidUpdates.flatMap { $0 }), Set(models))
        }
    }

    func testStoreUpdatesAndDeletes() throws {
        let start1 = [
            with(TestStoreModel1()) {
                $0.identifier = "s1/start_id1s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = "start_val1"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s1/start_id2s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = "start_val2"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s1/start_id3s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = "start_val3"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s1/start_id4s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = "start_val4"
            },
        ]
        let start2 = [
            with(TestStoreModel1()) {
                $0.identifier = "s2/start_id1s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = "start_val1"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s2/start_id2s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = "start_val2"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s2/start_id3s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = "start_val3"
            },
            with(TestStoreModel1()) {
                $0.identifier = "s2/start_id4s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = "start_val4"
            },
        ]

        let insertedSources1 = [
            TestStoreSource1(id: "ins_id1s1", value: "ins_val1"),
            TestStoreSource1(id: "ins_id2s1", value: "ins_val2"),
        ]
        let insertedSources2 = [
            TestStoreSource1(id: "ins_id1s2", value: "ins_val1"),
            TestStoreSource1(id: "ins_id2s2", value: "ins_val2"),
        ]

        let updatedSources1 = [
            TestStoreSource1(id: "start_id1s1", value: "start_val1-2"),
            TestStoreSource1(id: "start_id2s1", value: "start_val2-2"),
        ]
        let updatedSources2 = [
            TestStoreSource1(id: "start_id1s2", value: "start_val1-2"),
            TestStoreSource1(id: "start_id2s2", value: "start_val2-2"),
        ]

        try testQueue.sync {
            try realm.write {
                realm.add(start1)
                realm.add(start2)
            }

            try hang(manager.store(
                type: TestStoreModel1.self,
                from: api1.server,
                sourceModels: insertedSources1 + updatedSources1
            ))
            try hang(manager.store(
                type: TestStoreModel1.self,
                from: api2.server,
                sourceModels: insertedSources2 + updatedSources2
            ))
            let models = realm.objects(TestStoreModel1.self).sorted(byKeyPath: #keyPath(TestStoreModel1.value))
            XCTAssertEqual(models.count, 8)

            // inserted
            XCTAssertEqual(models[0].identifier, "s1/ins_id1s1")
            XCTAssertEqual(models[0].value, "ins_val1")
            XCTAssertEqual(models[1].identifier, "s2/ins_id1s2")
            XCTAssertEqual(models[1].value, "ins_val1")
            XCTAssertEqual(models[2].identifier, "s1/ins_id2s1")
            XCTAssertEqual(models[2].value, "ins_val2")
            XCTAssertEqual(models[3].identifier, "s2/ins_id2s2")
            XCTAssertEqual(models[3].value, "ins_val2")

            // updated
            XCTAssertEqual(models[4].identifier, "s1/start_id1s1")
            XCTAssertEqual(models[4].value, "start_val1-2")
            XCTAssertEqual(models[5].identifier, "s2/start_id1s2")
            XCTAssertEqual(models[5].value, "start_val1-2")
            XCTAssertEqual(models[6].identifier, "s1/start_id2s1")
            XCTAssertEqual(models[6].value, "start_val2-2")
            XCTAssertEqual(models[7].identifier, "s2/start_id2s2")
            XCTAssertEqual(models[7].value, "start_val2-2")

            // deleted
            XCTAssertEqual(Set(TestStoreModel1.lastWillDeleteIds.flatMap { $0 }), Set([
                "s1/start_id3s1",
                "s1/start_id4s1",
                "s2/start_id3s2",
                "s2/start_id4s2",
            ]))
        }
    }

    func testIneligibleNotDeleted() throws {
        let start1 = [
            with(TestStoreModel3()) {
                $0.identifier = "s1/start_id1s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = 10 // eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "s1/start_id2s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = 1 // not eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "s1/start_id3s1"
                $0.serverIdentifier = api1.server.identifier.rawValue
                $0.value = 100 // eligible, will be deleted
            },
        ]
        let start2 = [
            with(TestStoreModel3()) {
                $0.identifier = "s2/start_id1s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = 10 // eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "s2/start_id2s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = 1 // not eligible
            },
            with(TestStoreModel3()) {
                $0.identifier = "s2/start_id3s2"
                $0.serverIdentifier = api2.server.identifier.rawValue
                $0.value = 100 // eligible, will be deleted
            },
        ]

        let insertedSources1 = [
            TestStoreSource2(id: "ins_id1s1", value: 100),
        ]
        let insertedSources2 = [
            TestStoreSource2(id: "ins_id1s2", value: 100),
        ]

        let updatedSources1 = [
            TestStoreSource2(id: "start_id1s1", value: 4),
        ]
        let updatedSources2 = [
            TestStoreSource2(id: "start_id1s2", value: 4),
        ]

        try testQueue.sync {
            try realm.write {
                realm.add(start1)
                realm.add(start2)
            }

            try hang(manager.store(
                type: TestStoreModel3.self,
                from: api1.server,
                sourceModels: insertedSources1 + updatedSources1
            ))
            try hang(manager.store(
                type: TestStoreModel3.self,
                from: api2.server,
                sourceModels: insertedSources2 + updatedSources2
            ))
            let models = realm.objects(TestStoreModel3.self).sorted(byKeyPath: #keyPath(TestStoreModel3.value))
            XCTAssertEqual(models.count, 6)

            XCTAssertEqual(models[0].identifier, "s1/start_id2s1")
            XCTAssertEqual(models[0].value, 1)
            XCTAssertEqual(models[1].identifier, "s2/start_id2s2")
            XCTAssertEqual(models[1].value, 1)
            XCTAssertEqual(models[2].identifier, "s1/start_id1s1")
            XCTAssertEqual(models[2].value, 4)
            XCTAssertEqual(models[3].identifier, "s2/start_id1s2")
            XCTAssertEqual(models[3].value, 4)
            XCTAssertEqual(models[4].identifier, "s1/ins_id1s1")
            XCTAssertEqual(models[4].value, 100)
            XCTAssertEqual(models[5].identifier, "s2/ins_id1s2")
            XCTAssertEqual(models[5].value, 100)
        }
    }

    func testUpdateFalseSkipsNewCreation() throws {
        try testQueue.sync {
            let sources: [TestStoreSource1] = [
                .init(id: "id1", value: "val1"),
                .init(id: "id2", value: "val2"),
            ]

            TestStoreModel1.updateFalseIds = ["id2"]

            try hang(manager.store(type: TestStoreModel1.self, from: api1.server, sourceModels: sources))
            let models = realm.objects(TestStoreModel1.self).sorted(byKeyPath: #keyPath(TestStoreModel1.identifier))
            XCTAssertEqual(models.count, 1)
            XCTAssertEqual(models[0].identifier, "s1/id1")
            XCTAssertEqual(models[0].value, "val1")
            XCTAssertEqual(Set(TestStoreModel1.lastDidUpdates.flatMap { $0 }), Set(models))
        }
    }
}

class TestDeleteModel1: Object {
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
        #keyPath(TestDeleteModel1.identifier)
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
        #keyPath(TestDeleteModel2.identifier)
    }
}

class TestDeleteModel3: Object {
    @objc dynamic var identifier: String = UUID().uuidString
    @objc dynamic var createdAt: Date

    init(_ createdAt: Date) {
        self.createdAt = createdAt
        super.init()
    }

    override required init() {
        self.createdAt = Date()
        super.init()
    }

    override class func primaryKey() -> String? {
        #keyPath(TestDeleteModel3.identifier)
    }
}

final class TestStoreModel1: Object, UpdatableModel {
    static var updateFalseIds = [String]()

    static var lastDidUpdates: [[TestStoreModel1]] = []
    static var lastWillDeleteIds: [[String]] = []
    static func didUpdate(objects: [TestStoreModel1], server: Server, realm: Realm) {
        lastDidUpdates.append(objects)
    }

    static func willDelete(objects: [TestStoreModel1], server: Server?, realm: Realm) {
        lastWillDeleteIds.append(objects.compactMap(\.identifier))
    }

    @objc dynamic var identifier: String?
    @objc dynamic var serverIdentifier: String?
    @objc dynamic var value: String?

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    override class func primaryKey() -> String? {
        #keyPath(TestStoreModel1.identifier)
    }

    static func serverIdentifierKey() -> String {
        #keyPath(TestStoreModel1.serverIdentifier)
    }

    func update(
        with object: TestStoreSource1,
        server: Server,
        using realm: Realm
    ) -> Bool {
        if self.realm == nil {
            serverIdentifier = server.identifier.rawValue
        } else {
            XCTAssertEqual(serverIdentifier, server.identifier.rawValue)
        }
        value = object.value

        if Self.updateFalseIds.contains(object.id) {
            return false
        } else {
            return true
        }
    }
}

struct TestStoreSource1: UpdatableModelSource {
    var primaryKey: String { id }

    var id: String = UUID().uuidString
    var value: String?
}

final class TestStoreModel2: Object, UpdatableModel {
    static func didUpdate(objects: [TestStoreModel2], server: Server, realm: Realm) {}

    static func willDelete(objects: [TestStoreModel2], server: Server?, realm: Realm) {}

    @objc dynamic var identifier: String?
    @objc dynamic var serverIdentifier: String?

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    override class func primaryKey() -> String? {
        nil
    }

    static func serverIdentifierKey() -> String {
        #keyPath(TestStoreModel2.serverIdentifier)
    }

    func update(
        with object: TestStoreSource1,
        server: Server,
        using realm: Realm
    ) -> Bool {
        XCTFail("not expected to be called in error scenario")
        return false
    }
}

struct TestStoreSource2: UpdatableModelSource {
    var primaryKey: String { id }

    var id: String = UUID().uuidString
    var value: Int = 0
}

final class TestStoreModel3: Object, UpdatableModel {
    static func didUpdate(objects: [TestStoreModel3], server: Server, realm: Realm) {}

    static var lastWillDeleteIds: [[String]] = []
    static func willDelete(objects: [TestStoreModel3], server: Server?, realm: Realm) {
        lastWillDeleteIds.append(objects.compactMap(\.identifier))
    }

    static var updateEligiblePredicate: NSPredicate {
        .init(format: "value > 5")
    }

    @objc dynamic var identifier: String?
    @objc dynamic var serverIdentifier: String?
    @objc dynamic var value: Int = 0

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    override class func primaryKey() -> String? {
        "identifier"
    }

    static func serverIdentifierKey() -> String {
        #keyPath(TestStoreModel3.serverIdentifier)
    }

    func update(
        with object: TestStoreSource2,
        server: Server,
        using realm: Realm
    ) -> Bool {
        if self.realm == nil {
            serverIdentifier = server.identifier.rawValue
        } else {
            XCTAssertEqual(serverIdentifier, server.identifier.rawValue)
        }
        value = object.value
        return true
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
