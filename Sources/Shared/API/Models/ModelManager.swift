import Foundation
import HAKit
import PromiseKit
import RealmSwift

public class ModelManager: ServerObserver {
    private var notificationTokens = [NotificationToken]()
    private var hakitTokens = [HACancellable]()
    private var subscribedSubscriptions = [SubscribeDefinition]()

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
        public enum CleanupType {
            case age(createdKey: String, duration: Measurement<UnitDuration>)
            case orphaned(serverIdentifierKey: String, allowedPredicate: NSPredicate)
        }

        public var model: Object.Type
        public var cleanupType: CleanupType

        public init(
            model: Object.Type,
            createdKey: String,
            duration: Measurement<UnitDuration> = .init(value: 256, unit: .hours)
        ) {
            self.model = model
            self.cleanupType = .age(createdKey: createdKey, duration: duration)
        }

        init<UM: Object & UpdatableModel>(
            orphansOf model: UM.Type
        ) {
            self.model = model
            self.cleanupType = .orphaned(
                serverIdentifierKey: model.serverIdentifierKey(),
                allowedPredicate: model.updateEligiblePredicate
            )
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
            CleanupDefinition(orphansOf: Action.self),
            CleanupDefinition(orphansOf: NotificationCategory.self),
            CleanupDefinition(orphansOf: RLMZone.self),
            CleanupDefinition(orphansOf: RLMScene.self),
        ]
    }

    public func cleanup(
        definitions: [CleanupDefinition] = CleanupDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        queue.async {
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
        let objects: Results<Object>

        switch definition.cleanupType {
        case let .age(createdKey: createdKey, duration: duration):
            let duration = duration.converted(to: .seconds).value
            let date = Current.date().addingTimeInterval(-duration)
            objects = realm
                .objects(definition.model)
                .filter("%K < %@", createdKey, date)
        case let .orphaned(serverIdentifierKey: serverIdentifierKey, allowedPredicate: allowedPredicate):
            let serverIdentifiers = Current.servers.all.map(\.identifier.rawValue)

            objects = realm.objects(definition.model)
                .filter(allowedPredicate)
                .filter("not %K in %@", serverIdentifierKey, serverIdentifiers)
        }

        if objects.isEmpty == false {
            Current.Log.info("\(definition.model): \(objects.count)")
            realm.delete(objects)
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
        definitions: [SubscribeDefinition] = SubscribeDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) {
        Current.servers.add(observer: self)

        subscribedSubscriptions.removeAll()
        hakitTokens.forEach { $0.cancel() }
        hakitTokens = definitions.flatMap { definition -> [HACancellable] in
            Current.apis.flatMap { api in
                definition.subscribe(api.connection, api.server, queue, self)
            }
        }
        subscribedSubscriptions = definitions
    }

    public struct FetchDefinition {
        public var update: (
            _ api: HomeAssistantAPI,
            _ connection: HAConnection,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> Promise<Void>

        public static var defaults: [Self] = [
            FetchDefinition(update: { api, _, queue, manager in
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
        on queue: DispatchQueue = .global(qos: .utility),
        apis: [HomeAssistantAPI] = Current.apis
    ) -> Promise<Void> {
        when(fulfilled: apis.map { api in
            when(fulfilled: definitions.map { $0.update(api, api.connection, queue, self) })
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
            let incomingIDs = Set(sourceModels.map(\.primaryKey))

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

                if let existing = realm.object(ofType: UM.self, forPrimaryKey: model.primaryKey) {
                    updating = existing
                } else {
                    Current.Log.verbose("creating \(model.primaryKey)")
                    updating = UM()
                }

                if updating.update(with: model, server: server, using: realm) {
                    return updating
                } else {
                    return nil
                }
            }

            realm.add(updatedModels, update: .all)
            UM.didUpdate(objects: updatedModels, realm: realm)
            UM.willDelete(objects: Array(deleteObjects), realm: realm)
            realm.delete(deleteObjects)
        }
    }

    public func serversDidChange(_ serverManager: ServerManager) {
        subscribe(definitions: subscribedSubscriptions)
    }
}
