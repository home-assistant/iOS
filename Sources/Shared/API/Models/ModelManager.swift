import Foundation
import HAKit
import PromiseKit
import RealmSwift

public class ModelManager: ServerObserver {
    private var notificationTokens = [NotificationToken]()
    private var hakitTokens = [HACancellable]()
    private var subscribedSubscriptions = [SubscribeDefinition]()
    private var cleanupDefinitions = [CleanupDefinition]()

    public var workQueue: DispatchQueue = .global(qos: .userInitiated)

    deinit {
        hakitTokens.forEach { $0.cancel() }
        notificationTokens.forEach { $0.invalidate() }
    }

    public func observe<T>(
        for collection: AnyRealmCollection<T>,
        handler: @escaping (AnyRealmCollection<T>) -> Promise<Void>
    ) {
        notificationTokens.append(collection.observe { change in
            switch change {
            case .initial:
                break
            case .update(let collection, deletions: _, insertions: _, modifications: _):
                handler(collection).cauterize()
            case let .error(error):
                Current.Log.error("failed to watch \(collection): \(error)")
            }
        })
    }

    public struct CleanupDefinition {
        public enum OrphanMode {
            case delete(handler: (Realm, [Object]) -> Void)
            case replace
        }

        public enum CleanupType {
            case age(createdKey: String, duration: Measurement<UnitDuration>)
            case orphaned(serverIdentifierKey: String, allowedPredicate: NSPredicate, mode: OrphanMode)
        }

        public var model: Object.Type
        public var cleanupTypes: [CleanupType]

        public init(
            model: Object.Type,
            createdKey: String,
            duration: Measurement<UnitDuration> = .init(value: 256, unit: .hours)
        ) {
            self.model = model
            self.cleanupTypes = [.age(createdKey: createdKey, duration: duration)]
        }

        init<UM: Object & UpdatableModel>(
            orphansOf model: UM.Type
        ) {
            self.model = model
            self.cleanupTypes = [
                .orphaned(
                    serverIdentifierKey: model.serverIdentifierKey(),
                    allowedPredicate: model.updateEligiblePredicate,
                    mode: .delete(handler: { realm, objects in
                        if let objects = objects as? [UM] {
                            model.willDelete(objects: objects, server: nil, realm: realm)
                        } else {
                            preconditionFailure("invalid object type passed into delete handler")
                        }
                    })
                ),
                .orphaned(
                    serverIdentifierKey: model.serverIdentifierKey(),
                    allowedPredicate: NSCompoundPredicate(notPredicateWithSubpredicate: model.updateEligiblePredicate),
                    mode: .replace
                ),
            ]
        }

        public init(
            orphansOf model: Object.Type,
            serverIdentifierKey: String,
            allowedPredicate: NSPredicate,
            mode: OrphanMode
        ) {
            self.model = model
            self.cleanupTypes = [
                .orphaned(
                    serverIdentifierKey: serverIdentifierKey,
                    allowedPredicate: allowedPredicate,
                    mode: mode
                ),
            ]
        }

        public static var defaults: [Self] = [
            CleanupDefinition(
                model: LocationHistoryEntry.self,
                createdKey: #keyPath(LocationHistoryEntry.CreatedAt)
            ),
            CleanupDefinition(
                model: LocationError.self,
                createdKey: #keyPath(LocationError.CreatedAt)
            ),
            CleanupDefinition(
                model: ClientEvent.self,
                createdKey: #keyPath(ClientEvent.date)
            ),
            CleanupDefinition(orphansOf: RLMScene.self),
            CleanupDefinition(orphansOf: RLMZone.self),
            CleanupDefinition(orphansOf: Action.self),
            CleanupDefinition(orphansOf: NotificationCategory.self),
            CleanupDefinition(
                orphansOf: WatchComplication.self,
                serverIdentifierKey: #keyPath(WatchComplication.serverIdentifier),
                allowedPredicate: .init(value: true),
                mode: .replace
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
            let realm = Current.realm()
            let writes = definitions.map { definition in
                realm.reentrantWrite {
                    self.cleanup(using: definition, realm: realm)
                }
            }

            when(fulfilled: writes).pipe(to: seal.resolve)
        }

        return promise
    }

    private func cleanup(
        using definition: CleanupDefinition,
        realm: Realm
    ) {
        let deleteObjects = { (_ objects: Results<Object>) in
            if objects.isEmpty == false {
                Current.Log.info("delete \(definition.model): \(objects.count)")
                realm.delete(objects)
            }
        }

        for cleanupType in definition.cleanupTypes {
            switch cleanupType {
            case let .age(createdKey: createdKey, duration: duration):
                let duration = duration.converted(to: .seconds).value
                let date = Current.date().addingTimeInterval(-duration)
                deleteObjects(
                    realm
                        .objects(definition.model)
                        .filter("%K < %@", createdKey, date)
                )
            case let .orphaned(
                serverIdentifierKey: serverIdentifierKey,
                allowedPredicate: allowedPredicate,
                mode: mode
            ):
                let serverIdentifiers = Current.servers.all.map(\.identifier.rawValue)
                let objects = realm.objects(definition.model)
                    .filter(allowedPredicate)
                    .filter("not %K in %@", serverIdentifierKey, serverIdentifiers)

                switch mode {
                case let .delete(handler):
                    handler(realm, Array(objects))
                    deleteObjects(objects)
                case .replace:
                    if let replacement = Current.servers.all.first, !objects.isEmpty {
                        Current.Log.info("migrate \(definition.model): \(objects.count) to \(replacement.identifier)")
                        for object in objects {
                            object[serverIdentifierKey] = replacement.identifier.rawValue
                        }
                    }
                }
            }
        }
    }

    public struct SubscribeDefinition {
        public var subscribe: (
            _ connection: HAConnection,
            _ server: Server,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> [HACancellable]

        static func states<
            UM: Object & UpdatableModel
        >(
            domain: String,
            type: UM.Type
        ) -> Self where UM.Source == HAEntity {
            .init(subscribe: { connection, server, queue, manager in
                // working around a swift compiler crash, xcode 12.4
                let someManager = manager

                var lastEntities = Set<HAEntity>()

                return [
                    connection.caches.states.subscribe { [weak someManager] token, value in
                        queue.async {
                            guard let manager = someManager else {
                                token.cancel()
                                return
                            }

                            let entities = value.all.filter { $0.domain == domain }
                            if entities != lastEntities {
                                manager.store(type: type, from: server, sourceModels: entities).cauterize()
                                lastEntities = entities
                            }
                        }
                    },
                ]
            })
        }

        public static var defaults: [Self] = [
            .states(domain: "zone", type: RLMZone.self),
            .states(domain: "scene", type: RLMScene.self),
        ]
    }

    public func subscribe(
        definitions: [SubscribeDefinition] = SubscribeDefinition.defaults
    ) {
        Current.servers.add(observer: self)

        subscribedSubscriptions.removeAll()
        hakitTokens.forEach { $0.cancel() }
        hakitTokens = definitions.flatMap { definition -> [HACancellable] in
            Current.apis.flatMap { api in
                definition.subscribe(api.connection, api.server, workQueue, self)
            }
        }
        subscribedSubscriptions = definitions
    }

    public struct FetchDefinition {
        public var update: (
            _ api: HomeAssistantAPI,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> Promise<Void>

        public static var defaults: [Self] = [
            FetchDefinition(update: { api, queue, manager in
                api.GetMobileAppConfig().then(on: queue) {
                    when(fulfilled: [
                        manager.store(
                            type: NotificationCategory.self,
                            from: api.server,
                            sourceModels: $0.push.categories
                        ),
                        manager.store(type: Action.self, from: api.server, sourceModels: $0.actions),
                    ])
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

    internal enum StoreError: Error {
        case missingPrimaryKey
    }

    internal func store<UM: Object & UpdatableModel, C: Collection>(
        type realmObjectType: UM.Type,
        from server: Server,
        sourceModels: C
    ) -> Promise<Void> where C.Element == UM.Source {
        let realm = Current.realm()
        return realm.reentrantWrite {
            guard let realmPrimaryKey = realmObjectType.primaryKey() else {
                Current.Log.error("invalid realm object type: \(realmObjectType)")
                throw StoreError.missingPrimaryKey
            }

            let allObjects = realm.objects(UM.self)
                .filter(UM.updateEligiblePredicate)
                .filter("%K = %@", UM.serverIdentifierKey(), server.identifier.rawValue)

            let existingIDs = Set(allObjects.compactMap { $0[realmPrimaryKey] as? String })
            let incomingIDs = Set(sourceModels.map {
                UM.primaryKey(sourceIdentifier: $0.primaryKey, serverIdentifier: server.identifier.rawValue)
            })

            let deletedIDs = existingIDs.subtracting(incomingIDs)
            let newIDs = incomingIDs.subtracting(existingIDs)

            let deleteObjects = allObjects
                .filter("%K in %@", realmPrimaryKey, deletedIDs)

            Current.Log.verbose(
                [
                    "updating \(UM.self)",
                    "server(\(server.identifier))",
                    "from(\(existingIDs.count))",
                    "eligible(\(incomingIDs.count))",
                    "deleted(\(deleteObjects.count))",
                    "ignored(\(deletedIDs.count - deleteObjects.count))",
                    "new(\(newIDs.count))",
                ].joined(separator: " ")
            )

            let updatedModels: [UM] = sourceModels.compactMap { model in
                let updating: UM

                let fullPrimaryKey = UM.primaryKey(
                    sourceIdentifier: model.primaryKey,
                    serverIdentifier: server.identifier.rawValue
                )

                if let existing = realm.object(ofType: UM.self, forPrimaryKey: fullPrimaryKey) {
                    updating = existing
                } else {
                    Current.Log.verbose("creating \(fullPrimaryKey)")
                    updating = UM()
                }

                if updating.realm == nil {
                    updating.setValue(fullPrimaryKey, forKey: realmPrimaryKey)
                } else {
                    assert(updating.value(forKey: realmPrimaryKey) as? String == fullPrimaryKey)
                }

                updating.setValue(server.identifier.rawValue, forKey: UM.serverIdentifierKey())

                if updating.update(with: model, server: server, using: realm) {
                    return updating
                } else {
                    return nil
                }
            }

            realm.add(updatedModels, update: .all)
            UM.didUpdate(objects: updatedModels, server: server, realm: realm)
            UM.willDelete(objects: Array(deleteObjects), server: server, realm: realm)
            realm.delete(deleteObjects)
        }
    }

    public func serversDidChange(_ serverManager: ServerManager) {
        subscribe(definitions: subscribedSubscriptions)
        cleanup(definitions: cleanupDefinitions).cauterize()
    }
}
