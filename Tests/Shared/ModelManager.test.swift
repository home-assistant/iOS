import Foundation
import GRDB
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import XCTest

class ModelManagerTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var testQueue: DispatchQueue!
    private var manager: LegacyModelManager!
    private var servers: FakeServerManager!
    private var api1: FakeHomeAssistantAPI!
    private var api2: FakeHomeAssistantAPI!
    private var apiConnection1: HAMockConnection!
    private var apiConnection2: HAMockConnection!

    override func setUpWithError() throws {
        try super.setUpWithError()

        testQueue = DispatchQueue(label: #file)
        manager = LegacyModelManager()
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

        database = try DatabaseQueue()
        try database.write { db in
            try db.create(table: TestStoreModel1.databaseTableName) { t in
                t.primaryKey("identifier", .text).notNull()
                t.column("serverIdentifier", .text).notNull()
                t.column("value", .text)
            }
            try db.create(table: TestStoreModel3.databaseTableName) { t in
                t.primaryKey("identifier", .text).notNull()
                t.column("serverIdentifier", .text).notNull()
                t.column("value", .integer).notNull()
            }
            for tableName in [
                TestDeleteModel1.databaseTableName,
                TestDeleteModel2.databaseTableName,
                TestDeleteModel3.databaseTableName,
            ] {
                try db.create(table: tableName) { t in
                    t.primaryKey("identifier", .text).notNull()
                    t.column("createdAt", .datetime).notNull()
                }
            }
        }

        previousDatabase = Current.database
        Current.database = { self.database }
    }

    override func tearDown() {
        Current.database = previousDatabase
        TestStoreModel1.updateFalseIds = []

        super.tearDown()
    }

    func testObserve() throws {
        let initialExpectation = expectation(description: "initial")
        let updateExpectation = expectation(description: "update")

        var observed: [[TestStoreModel1]] = []

        manager.observe(for: TestStoreModel1.self) { models -> Promise<Void> in
            observed.append(models)
            if observed.count == 1 {
                initialExpectation.fulfill()
            } else if observed.count == 2 {
                updateExpectation.fulfill()
            }
            return .value(())
        }

        wait(for: [initialExpectation], timeout: 10.0)
        XCTAssertEqual(observed.last, [])

        try database.write { db in
            try TestStoreModel1(identifier: "123", serverIdentifier: "s1", value: "456").save(db)
        }

        wait(for: [updateExpectation], timeout: 10.0)
        XCTAssertEqual(observed.last?.map(\.identifier), ["123"])
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

        try database.write { db in
            for model in models {
                try model.save(db)
            }
        }

        let promise = manager.cleanup(
            definitions: [
                .age(
                    recordType: TestDeleteModel1.self,
                    createdColumnName: "createdAt",
                    duration: .init(value: 100, unit: .seconds)
                ),
            ]
        )

        XCTAssertNoThrow(try hang(promise))
        XCTAssertEqual(try database.read { try TestDeleteModel1.fetchCount($0) }, models.count)
    }

    func testCleanupRemovesOnlyOlder() throws {
        let now = Date()

        let deletedTimeInterval1: TimeInterval = 100
        let deletedTimeInterval2: TimeInterval = 1000

        let deletedLimit1 = Date(timeIntervalSinceNow: -deletedTimeInterval1)
        let deletedLimit2 = Date(timeIntervalSinceNow: -deletedTimeInterval2)

        Current.date = { now }

        let expired1 = [
            TestDeleteModel1(deletedLimit1.addingTimeInterval(-1)),
            TestDeleteModel1(deletedLimit1.addingTimeInterval(-100)),
            TestDeleteModel1(deletedLimit1.addingTimeInterval(-1000)),
        ]
        let expired2 = [
            TestDeleteModel2(deletedLimit2.addingTimeInterval(-1)),
            TestDeleteModel2(deletedLimit2.addingTimeInterval(-100)),
            TestDeleteModel2(deletedLimit2.addingTimeInterval(-1000)),
        ]

        let alive1 = [
            // shouldn't be deleted due to time
            TestDeleteModel1(deletedLimit1),
            TestDeleteModel1(deletedLimit1.addingTimeInterval(10)),
            TestDeleteModel1(deletedLimit1.addingTimeInterval(100)),
        ]
        let alive2 = [
            TestDeleteModel2(deletedLimit2),
            TestDeleteModel2(deletedLimit2.addingTimeInterval(10)),
            TestDeleteModel2(deletedLimit2.addingTimeInterval(100)),
        ]
        let alive3 = [
            // shouldn't be deleted due to not being requested
            TestDeleteModel3(now.addingTimeInterval(-10000)),
        ]

        try database.write { db in
            for model in expired1 {
                try model.save(db)
            }
            for model in expired2 {
                try model.save(db)
            }
            for model in alive1 {
                try model.save(db)
            }
            for model in alive2 {
                try model.save(db)
            }
            for model in alive3 {
                try model.save(db)
            }
        }

        let promise = manager.cleanup(
            definitions: [
                .age(
                    recordType: TestDeleteModel1.self,
                    createdColumnName: "createdAt",
                    duration: .init(value: deletedTimeInterval1, unit: .seconds)
                ),
                .age(
                    recordType: TestDeleteModel2.self,
                    createdColumnName: "createdAt",
                    duration: .init(value: deletedTimeInterval2, unit: .seconds)
                ),
            ]
        )

        XCTAssertNoThrow(try hang(promise))

        let remaining1 = try database.read { try TestDeleteModel1.fetchAll($0) }
        let remaining2 = try database.read { try TestDeleteModel2.fetchAll($0) }
        let remaining3 = try database.read { try TestDeleteModel3.fetchAll($0) }

        XCTAssertEqual(Set(remaining1.map(\.identifier)), Set(alive1.map(\.identifier)))
        XCTAssertEqual(Set(remaining2.map(\.identifier)), Set(alive2.map(\.identifier)))
        XCTAssertEqual(Set(remaining3.map(\.identifier)), Set(alive3.map(\.identifier)))
    }

    func testCleanupMissingServers() throws {
        let server3 = servers.addFake()
        let api3 = FakeHomeAssistantAPI(server: server3)
        Current.cachedApis[server3.identifier] = api3

        let start1 = [
            TestStoreModel1(identifier: "s1m1", serverIdentifier: "s1", value: nil),
            TestStoreModel1(identifier: "s1m2", serverIdentifier: "s1", value: nil),
            TestStoreModel1(identifier: "s1m3", serverIdentifier: "s1", value: nil),
            TestStoreModel1(identifier: "s2m1", serverIdentifier: "s2", value: nil),
            TestStoreModel1(identifier: "s2m2", serverIdentifier: "s2", value: nil),
            TestStoreModel1(identifier: "s2m3", serverIdentifier: "s2", value: nil),
            TestStoreModel1(identifier: "s3m1", serverIdentifier: server3.identifier.rawValue, value: nil),
            TestStoreModel1(identifier: "s3m2", serverIdentifier: server3.identifier.rawValue, value: nil),
            TestStoreModel1(identifier: "s3m3", serverIdentifier: server3.identifier.rawValue, value: nil),
        ]
        let start3 = [
            TestStoreModel3(identifier: "s1m4", serverIdentifier: "s1", value: 1), // not deleted
            TestStoreModel3(identifier: "s1m5", serverIdentifier: "s1", value: 6),
            TestStoreModel3(identifier: "s1m6", serverIdentifier: "s1", value: 8),
            TestStoreModel3(identifier: "s2m4", serverIdentifier: "s2", value: 1), // reassigned
            TestStoreModel3(identifier: "s2m5", serverIdentifier: "s2", value: 6), // deleted
            TestStoreModel3(identifier: "s2m6", serverIdentifier: "s2", value: 8), // deleted
            TestStoreModel3(identifier: "s3m4", serverIdentifier: server3.identifier.rawValue, value: 1),
            TestStoreModel3(identifier: "s3m5", serverIdentifier: server3.identifier.rawValue, value: 6),
            TestStoreModel3(identifier: "s3m6", serverIdentifier: server3.identifier.rawValue, value: 8),
        ]

        manager.cleanup(definitions: [
            .orphanDelete(
                recordType: TestStoreModel1.self,
                serverIdentifierColumnName: "serverIdentifier"
            ),
            .orphanDelete(
                recordType: TestStoreModel3.self,
                serverIdentifierColumnName: "serverIdentifier",
                condition: (Column("value") > 5).sqlExpression
            ),
            .orphanReassign(
                recordType: TestStoreModel3.self,
                serverIdentifierColumnName: "serverIdentifier",
                condition: (Column("value") <= 5).sqlExpression
            ),
        ]).cauterize()

        try database.write { db in
            for model in start1 {
                try model.save(db)
            }
            for model in start3 {
                try model.save(db)
            }
        }

        servers.remove(identifier: api2.server.identifier)
        servers.notify()

        // ensure the cleanup triggered by the server change has finished
        testQueue.sync {}

        let remaining1 = try database.read { try TestStoreModel1.fetchAll($0) }
        let remaining3 = try database.read { try TestStoreModel3.fetchAll($0) }

        XCTAssertEqual(Set(remaining1.map(\.identifier)), Set([
            "s1m1", "s1m2", "s1m3",
            "s3m1", "s3m2", "s3m3",
        ]))
        XCTAssertEqual(Set(remaining3.map(\.identifier)), Set([
            "s1m4", "s1m5", "s1m6",
            "s2m4",
            "s3m4", "s3m5", "s3m6",
        ]))

        let reassigned = try XCTUnwrap(remaining3.first(where: { $0.identifier == "s2m4" }))
        XCTAssertEqual(reassigned.serverIdentifier, servers.all.first?.identifier.rawValue)
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

        let definitions: [LegacyModelManager.SubscribeDefinition] = [
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

        manager.subscribe(definitions: definitions, isAppInForeground: { true })

        func verify(apis: [HomeAssistantAPI]) {
            XCTAssertEqual(handlers1APIs.map(\.1), apis.map(\.server))
            XCTAssertEqual(handlers2APIs.map(\.1), apis.map(\.server))
            XCTAssertEqual(
                handlers1APIs.map(\.0).map(ObjectIdentifier.init(_:)),
                apis.compactMap(\.connection).map(ObjectIdentifier.init(_:))
            )
        }

        verify(apis: [api1, api2])

        XCTAssertTrue(handlers1_1.allSatisfy { !$0.wasCancelled })
        XCTAssertTrue(handlers2_1.allSatisfy { !$0.wasCancelled })

        handlers1Iterator = handlers1_2.makeIterator()
        handlers2Iterator = handlers2_2.makeIterator()

        handlers1APIs.removeAll()
        handlers2APIs.removeAll()

        manager.subscribe(definitions: definitions, isAppInForeground: { true })

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
        try hang(manager.store(type: TestStoreModel1.self, from: api1.server, sourceModels: []))
        XCTAssertEqual(try database.read { try TestStoreModel1.fetchCount($0) }, 0)
    }

    func testStoreWithoutExistingObjects() throws {
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

        let models = try database.read {
            try TestStoreModel1.order(Column("identifier")).fetchAll($0)
        }
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
    }

    func testStoreUpdatesAndDeletes() throws {
        let start = [
            TestStoreModel1(identifier: "s1/start_id1s1", serverIdentifier: "s1", value: "start_val1"),
            TestStoreModel1(identifier: "s1/start_id2s1", serverIdentifier: "s1", value: "start_val2"),
            TestStoreModel1(identifier: "s1/start_id3s1", serverIdentifier: "s1", value: "start_val3"),
            TestStoreModel1(identifier: "s1/start_id4s1", serverIdentifier: "s1", value: "start_val4"),
            TestStoreModel1(identifier: "s2/start_id1s2", serverIdentifier: "s2", value: "start_val1"),
            TestStoreModel1(identifier: "s2/start_id2s2", serverIdentifier: "s2", value: "start_val2"),
            TestStoreModel1(identifier: "s2/start_id3s2", serverIdentifier: "s2", value: "start_val3"),
            TestStoreModel1(identifier: "s2/start_id4s2", serverIdentifier: "s2", value: "start_val4"),
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

        try database.write { db in
            for model in start {
                try model.save(db)
            }
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

        let models = try database.read {
            try TestStoreModel1.order(Column("value"), Column("identifier")).fetchAll($0)
        }
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
        XCTAssertFalse(models.contains(where: { $0.identifier.contains("start_id3") }))
        XCTAssertFalse(models.contains(where: { $0.identifier.contains("start_id4") }))
    }

    func testIneligibleNotDeleted() throws {
        let start = [
            TestStoreModel3(identifier: "s1/start_id1s1", serverIdentifier: "s1", value: 10), // eligible
            TestStoreModel3(identifier: "s1/start_id2s1", serverIdentifier: "s1", value: 1), // not eligible
            TestStoreModel3(identifier: "s1/start_id3s1", serverIdentifier: "s1", value: 100), // eligible, deleted
            TestStoreModel3(identifier: "s2/start_id1s2", serverIdentifier: "s2", value: 10), // eligible
            TestStoreModel3(identifier: "s2/start_id2s2", serverIdentifier: "s2", value: 1), // not eligible
            TestStoreModel3(identifier: "s2/start_id3s2", serverIdentifier: "s2", value: 100), // eligible, deleted
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

        try database.write { db in
            for model in start {
                try model.save(db)
            }
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

        let models = try database.read {
            try TestStoreModel3.order(Column("value"), Column("identifier")).fetchAll($0)
        }
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

    func testUpdateFalseSkipsNewCreation() throws {
        let sources: [TestStoreSource1] = [
            .init(id: "id1", value: "val1"),
            .init(id: "id2", value: "val2"),
        ]

        TestStoreModel1.updateFalseIds = ["id2"]

        try hang(manager.store(type: TestStoreModel1.self, from: api1.server, sourceModels: sources))

        let models = try database.read {
            try TestStoreModel1.order(Column("identifier")).fetchAll($0)
        }
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models[0].identifier, "s1/id1")
        XCTAssertEqual(models[0].value, "val1")
    }
}

struct TestDeleteModel1: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "testDeleteModel1"

    var identifier: String
    var createdAt: Date

    init(_ createdAt: Date) {
        self.identifier = UUID().uuidString
        self.createdAt = createdAt
    }
}

struct TestDeleteModel2: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "testDeleteModel2"

    var identifier: String
    var createdAt: Date

    init(_ createdAt: Date) {
        self.identifier = UUID().uuidString
        self.createdAt = createdAt
    }
}

struct TestDeleteModel3: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "testDeleteModel3"

    var identifier: String
    var createdAt: Date

    init(_ createdAt: Date) {
        self.identifier = UUID().uuidString
        self.createdAt = createdAt
    }
}

struct TestStoreModel1: Codable, FetchableRecord, PersistableRecord, UpdatableModel, Equatable {
    static let databaseTableName = "testStoreModel1"

    static var updateFalseIds = [String]()

    var identifier: String
    var serverIdentifier: String
    var value: String?

    static var serverIdentifierColumnName: String { "serverIdentifier" }
    static var primaryKeyColumnName: String { "identifier" }

    var primaryKeyValue: String { identifier }

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    init(identifier: String, serverIdentifier: String, value: String?) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.value = value
    }

    init(primaryKey: String, serverIdentifier: String) {
        self.init(identifier: primaryKey, serverIdentifier: serverIdentifier, value: nil)
    }

    mutating func update(with object: TestStoreSource1, server: Server) -> Bool {
        XCTAssertEqual(serverIdentifier, server.identifier.rawValue)
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

struct TestStoreSource2: UpdatableModelSource {
    var primaryKey: String { id }

    var id: String = UUID().uuidString
    var value: Int = 0
}

struct TestStoreModel3: Codable, FetchableRecord, PersistableRecord, UpdatableModel, Equatable {
    static let databaseTableName = "testStoreModel3"

    var identifier: String
    var serverIdentifier: String
    var value: Int

    static var serverIdentifierColumnName: String { "serverIdentifier" }
    static var primaryKeyColumnName: String { "identifier" }
    static var updateEligibleCondition: SQLExpression? {
        (Column("value") > 5).sqlExpression
    }

    var primaryKeyValue: String { identifier }

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String {
        serverIdentifier + "/" + sourceIdentifier
    }

    init(identifier: String, serverIdentifier: String, value: Int) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.value = value
    }

    init(primaryKey: String, serverIdentifier: String) {
        self.init(identifier: primaryKey, serverIdentifier: serverIdentifier, value: 0)
    }

    mutating func update(with object: TestStoreSource2, server: Server) -> Bool {
        XCTAssertEqual(serverIdentifier, server.identifier.rawValue)
        value = object.value
        return true
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
