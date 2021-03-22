import Foundation
import HAKit
import PromiseKit
import RealmSwift

public final class ModelManager {
    private var notificationTokens = [NotificationToken]()
    private var hakitTokens = [HACancellable]()

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
        public var model: Object.Type
        public var createdKey: String
        public var duration: Measurement<UnitDuration>

        public init(
            model: Object.Type,
            createdKey: String,
            duration: Measurement<UnitDuration> = .init(value: 256, unit: .hours)
        ) {
            self.model = model
            self.createdKey = createdKey
            self.duration = duration
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
        ]
    }

    public func cleanup(
        definitions: [CleanupDefinition] = CleanupDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) -> Promise<Void> {
        let (promise, seal) = Promise<Void>.pending()

        queue.async {
            do {
                for definition in definitions {
                    try autoreleasepool {
                        let realm = Current.realm()
                        try realm.write {
                            self.cleanup(using: definition, realm: realm)
                        }
                    }
                }

                seal.fulfill(())
            } catch {
                Current.Log.error("failed to remove: \(error)")
                seal.reject(error)
            }
        }

        return promise
    }

    private func cleanup(
        using definition: CleanupDefinition,
        realm: Realm
    ) {
        let duration = definition.duration.converted(to: .seconds).value
        let date = Current.date().addingTimeInterval(-duration)
        let objects = realm
            .objects(definition.model)
            .filter("%K < %@", definition.createdKey, date)

        if objects.isEmpty == false {
            Current.Log.info("\(definition.model): \(objects.count)")
            realm.delete(objects)
        }
    }

    public struct SubscribeDefinition {
        public var subscribe: (
            _ connection: HAConnection,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> [HACancellable]

        static func states<
            UM: Object & UpdatableModel
        >(
            domain: String,
            type: UM.Type
        ) -> Self where UM.Source == HAEntity {
            .init(subscribe: { connection, queue, manager in
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

                            do {
                                let entities = value.all.filter { $0.domain == domain }
                                if entities != lastEntities {
                                    try manager.store(type: type, sourceModels: entities)
                                    lastEntities = entities
                                }
                            } catch {
                                Current.Log.error("failed to store \(type): \(error)")
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
        hakitTokens.forEach { $0.cancel() }
        hakitTokens = definitions.flatMap {
            $0.subscribe(Current.apiConnection, queue, self)
        }
    }

    public struct FetchDefinition {
        public var update: (
            _ api: HomeAssistantAPI,
            _ connection: HAConnection,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> Promise<Void>

        public static var defaults: [Self] = [
            .init(update: { api, _, queue, manager in
                api.GetMobileAppConfig()
                    .done(on: queue) {
                        try manager.store(type: NotificationCategory.self, sourceModels: $0.push.categories)
                        try manager.store(type: Action.self, sourceModels: $0.actions)
                    }
            }),
        ]
    }

    public func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) -> Promise<Void> {
        Current.api.then(on: nil) { api in
            when(fulfilled: definitions.map { $0.update(api, Current.apiConnection, queue, self) })
        }
    }

    internal enum StoreError: Error {
        case missingPrimaryKey
    }

    internal func store<UM: Object & UpdatableModel, C: Collection>(
        type realmObjectType: UM.Type,
        sourceModels: C
    ) throws where C.Element == UM.Source {
        let realm = Current.realm()
        try realm.write {
            guard let realmPrimaryKey = realmObjectType.primaryKey() else {
                Current.Log.error("invalid realm object type: \(realmObjectType)")
                throw StoreError.missingPrimaryKey
            }

            let existingIDs = Set(realm.objects(UM.self).compactMap { $0[realmPrimaryKey] as? String })
            let incomingIDs = Set(sourceModels.map(\.primaryKey))

            let deletedIDs = existingIDs.subtracting(incomingIDs)
            let newIDs = incomingIDs.subtracting(existingIDs)

            let deleteObjects = realm.objects(UM.self)
                .filter(UM.updateEligiblePredicate)
                .filter("%K in %@", realmPrimaryKey, deletedIDs)

            Current.Log.verbose(
                [
                    "updating \(UM.self)",
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

                if updating.update(with: model, using: realm) {
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
}
