import Foundation
import GRDB
import HAKit
import PromiseKit

// Legacy manager which was previously used to handle all model updates and cleanup.
// Now it is used just for zones and notification categories, persisted in GRDB.
public class LegacyModelManager: ServerObserver {
    private var observationTokens = [AnyDatabaseCancellable]()
    private var hakitTokens = [HACancellable]()
    private var subscribedSubscriptions = [SubscribeDefinition]()
    private var cleanupDefinitions = [CleanupDefinition]()

    private static var includedDomains: [Domain] = [.zone, .person]

    public var workQueue: DispatchQueue = .global(qos: .userInitiated)
    static var isAppInForeground: () -> Bool = { false }

    public init() {}

    deinit {
        hakitTokens.forEach { $0.cancel() }
        observationTokens.forEach { $0.cancel() }
        NotificationCenter.default.removeObserver(self)
    }

    /// Observes every row of the given record type, invoking the handler with
    /// the current values whenever they change (including once initially).
    public func observe<T: FetchableRecord & TableRecord>(
        for type: T.Type,
        handler: @escaping ([T]) -> Promise<Void>
    ) {
        let observation = ValueObservation.tracking { db in
            try T.fetchAll(db)
        }
        observationTokens.append(observation.start(
            in: Current.database(),
            onError: { error in
                Current.Log.error("failed to watch \(type): \(error)")
            },
            onChange: { values in
                handler(values).cauterize()
            }
        ))
    }

    public struct CleanupDefinition: @unchecked Sendable {
        public var cleanup: (Database, [String]) throws -> Void

        public init(cleanup: @escaping (Database, [String]) throws -> Void) {
            self.cleanup = cleanup
        }

        /// Deletes rows whose creation date is older than the given duration.
        public static func age(
            recordType: (some FetchableRecord & TableRecord).Type,
            createdColumnName: String,
            duration: Measurement<UnitDuration> = .init(value: 256, unit: .hours)
        ) -> Self {
            .init { db, _ in
                let duration = duration.converted(to: .seconds).value
                let date = Current.date().addingTimeInterval(-duration)
                let count = try recordType
                    .filter(Column(createdColumnName) < date)
                    .deleteAll(db)
                if count > 0 {
                    Current.Log.info("delete \(recordType): \(count)")
                }
            }
        }

        /// Deletes rows which belong to servers that no longer exist.
        public static func orphanDelete(
            recordType: (some FetchableRecord & TableRecord).Type,
            serverIdentifierColumnName: String,
            condition: SQLExpression? = nil
        ) -> Self {
            .init { db, serverIdentifiers in
                var request = recordType.filter(!serverIdentifiers.contains(Column(serverIdentifierColumnName)))
                if let condition {
                    request = request.filter(condition)
                }
                let count = try request.deleteAll(db)
                if count > 0 {
                    Current.Log.info("delete \(recordType): \(count)")
                }
            }
        }

        /// Reassigns rows which belong to servers that no longer exist to the
        /// first remaining server.
        public static func orphanReassign(
            recordType: (some FetchableRecord & TableRecord).Type,
            serverIdentifierColumnName: String,
            condition: SQLExpression? = nil
        ) -> Self {
            .init { db, serverIdentifiers in
                guard let replacement = serverIdentifiers.first else { return }
                var request = recordType.filter(!serverIdentifiers.contains(Column(serverIdentifierColumnName)))
                if let condition {
                    request = request.filter(condition)
                }
                let count = try request.updateAll(db, Column(serverIdentifierColumnName).set(to: replacement))
                if count > 0 {
                    Current.Log.info("migrate \(recordType): \(count) to \(replacement)")
                }
            }
        }

        public static let defaults: [Self] = [
            .age(
                recordType: LocationHistoryEntry.self,
                createdColumnName: DatabaseTables.LocationHistory.createdAt.rawValue
            ),
            .age(
                recordType: LocationError.self,
                createdColumnName: DatabaseTables.LocationError.createdAt.rawValue
            ),
            .orphanDelete(
                recordType: AppZone.self,
                serverIdentifierColumnName: DatabaseTables.AppZone.serverIdentifier.rawValue
            ),
            .orphanDelete(
                recordType: NotificationCategory.self,
                serverIdentifierColumnName: DatabaseTables.NotificationCategory.serverIdentifier.rawValue,
                condition: (Column(DatabaseTables.NotificationCategory.isServerControlled.rawValue) == true)
                    .sqlExpression
            ),
            .orphanReassign(
                recordType: NotificationCategory.self,
                serverIdentifierColumnName: DatabaseTables.NotificationCategory.serverIdentifier.rawValue,
                condition: (Column(DatabaseTables.NotificationCategory.isServerControlled.rawValue) == false)
                    .sqlExpression
            ),
        ]
    }

    public func cleanup(
        definitions: [CleanupDefinition] = CleanupDefinition.defaults
    ) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        Current.servers.add(observer: self)

        cleanupDefinitions = definitions
        workQueue.async {
            let serverIdentifiers = Current.servers.all.map(\.identifier.rawValue)

            try? WatchComplication.deleteOrphans(keepingServerIdentifiers: serverIdentifiers)
            try? WatchComplicationConfig.deleteOrphans(keepingServerIds: serverIdentifiers)

            do {
                try Current.database().write { db in
                    for definition in definitions {
                        try definition.cleanup(db, serverIdentifiers)
                    }
                }
                seal.fulfill(())
            } catch {
                Current.Log.error("cleanup failed: \(error)")
                seal.reject(error)
            }
        }

        return promise
    }

    public struct SubscribeDefinition {
        public var subscribe: (
            _ connection: HAConnection,
            _ server: Server,
            _ queue: DispatchQueue,
            _ modelManager: LegacyModelManager
        ) -> [HACancellable]

        static func states<
            UM: UpdatableModel
        >(
            domain: String,
            type: UM.Type
        ) -> Self where UM.Source == HAEntity {
            .init(subscribe: { connection, server, queue, manager in
                // working around a swift compiler crash, xcode 12.4
                let someManager = manager
                var filter: [String: Any] = [:]
                var lastEntities = Set<HAEntity>()
                var lastUpdate: Date?

                if server.info.version > .canSubscribeEntitiesChangesWithFilter {
                    filter = [
                        "include": [
                            "domains": LegacyModelManager.includedDomains.map(\.rawValue),
                        ],
                    ]
                }

                return [
                    connection.caches.states(filter).subscribe { [weak someManager] token, value in
                        queue.async {
                            guard let manager = someManager else {
                                token.cancel()
                                return
                            }
                            DispatchQueue.main.async {
                                guard LegacyModelManager.isAppInForeground() else { return }
                                if let lastUpdate {
                                    // Prevent sequential updates in short time
                                    guard Date().timeIntervalSince(lastUpdate) > 15 else { return }
                                }

                                let entitiesForDomain = value.all.filter({ $0.domain == domain })
                                if entitiesForDomain != lastEntities {
                                    manager.store(type: type, from: server, sourceModels: entitiesForDomain).cauterize()
                                    lastEntities = entitiesForDomain
                                    lastUpdate = Date()
                                }
                            }
                        }
                    },
                ]
            })
        }

        public static let defaults: [Self] = [
            .states(domain: "zone", type: AppZone.self),
        ]
    }

    public func subscribe(
        definitions: [SubscribeDefinition] = SubscribeDefinition.defaults,
        isAppInForeground: @escaping () -> Bool
    ) {
        LegacyModelManager.isAppInForeground = isAppInForeground
        Current.servers.add(observer: self)

        subscribedSubscriptions.removeAll()
        hakitTokens.forEach { $0.cancel() }
        hakitTokens = definitions.flatMap { definition -> [HACancellable] in
            // Evaluated against cached network information: `Current.apis` already excludes servers
            // without a usable URL, and this synchronous subscribe path cannot refresh.
            Current.apis.filter({ $0.server.info.connection.evaluateActiveURL() != nil }).flatMap { api in
                definition.subscribe(api.connection, api.server, workQueue, self)
            }
        }
        subscribedSubscriptions = definitions
    }

    public func unsubscribe() {
        subscribedSubscriptions.removeAll()
        hakitTokens.forEach { $0.cancel() }
        subscribedSubscriptions = []
    }

    public struct FetchDefinition {
        public var update: (
            _ api: HomeAssistantAPI,
            _ queue: DispatchQueue,
            _ modelManager: LegacyModelManager
        ) -> Promise<Void>

        public init(update: @escaping (HomeAssistantAPI, DispatchQueue, LegacyModelManager) -> Promise<Void>) {
            self.update = update
        }

        public static let defaults: [Self] = [
            FetchDefinition(update: { api, queue, manager in
                api.GetMobileAppConfig().then(on: queue) {
                    manager.store(
                        type: NotificationCategory.self,
                        from: api.server,
                        sourceModels: $0.push.categories
                    )
                }
            }),
        ]
    }

    public func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        apis: [HomeAssistantAPI] = Current.apis
    ) -> Promise<Void> {
        when(fulfilled: apis.map { api in
            when(fulfilled: definitions.map { $0.update(api, workQueue, self) })
        }).asVoid()
    }

    func store<UM: UpdatableModel>(
        type recordType: UM.Type,
        from server: Server,
        sourceModels: some Collection<UM.Source>
    ) -> Promise<Void> {
        Promise { seal in
            workQueue.async {
                do {
                    try Current.database().write { db in
                        try Self.store(type: recordType, from: server, sourceModels: sourceModels, db: db)
                    }
                    seal.fulfill(())
                } catch {
                    Current.Log.error("store of \(recordType) failed: \(error)")
                    seal.reject(error)
                }
            }
        }
    }

    private static func store<UM: UpdatableModel>(
        type recordType: UM.Type,
        from server: Server,
        sourceModels: some Collection<UM.Source>,
        db: Database
    ) throws {
        var request = UM
            .filter(Column(UM.serverIdentifierColumnName) == server.identifier.rawValue)
        if let condition = UM.updateEligibleCondition {
            request = request.filter(condition)
        }

        let existing = try request.fetchAll(db)
        let existingIDs = Set(existing.map(\.primaryKeyValue))
        let incomingIDs = Set(sourceModels.map {
            UM.primaryKey(sourceIdentifier: $0.primaryKey, serverIdentifier: server.identifier.rawValue)
        })

        let deletedIDs = existingIDs.subtracting(incomingIDs)
        let newIDs = incomingIDs.subtracting(existingIDs)

        Current.Log.verbose(
            [
                "updating \(UM.self)",
                "server(\(server.identifier))",
                "from(\(existingIDs.count))",
                "eligible(\(incomingIDs.count))",
                "deleted(\(deletedIDs.count))",
                "new(\(newIDs.count))",
            ].joined(separator: " ")
        )

        for model in sourceModels {
            let fullPrimaryKey = UM.primaryKey(
                sourceIdentifier: model.primaryKey,
                serverIdentifier: server.identifier.rawValue
            )

            var updating: UM

            if let existing = try UM.filter(Column(UM.primaryKeyColumnName) == fullPrimaryKey).fetchOne(db) {
                updating = existing
            } else {
                Current.Log.verbose("creating \(fullPrimaryKey)")
                updating = UM(primaryKey: fullPrimaryKey, serverIdentifier: server.identifier.rawValue)
            }

            if updating.update(with: model, server: server) {
                try updating.save(db)
            }
        }

        if !deletedIDs.isEmpty {
            try UM
                .filter(Column(UM.serverIdentifierColumnName) == server.identifier.rawValue)
                .filter(deletedIDs.contains(Column(UM.primaryKeyColumnName)))
                .deleteAll(db)
        }
    }

    public func serversDidChange(_ serverManager: ServerManager) {
        subscribe(definitions: subscribedSubscriptions, isAppInForeground: LegacyModelManager.isAppInForeground)
        cleanup(definitions: cleanupDefinitions).cauterize()
    }
}
