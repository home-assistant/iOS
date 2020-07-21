import Foundation
import RealmSwift
import PromiseKit

public final class ModelManager {
    private var notificationTokens = [NotificationToken]()

    public func observe<T>(
        for collection: AnyRealmCollection<T>,
        handler: @escaping (AnyRealmCollection<T>) -> Promise<Void>
    ) {
        notificationTokens.append(collection.observe { change in
            switch change {
            case .initial(let collection),
                 .update(let collection, deletions: _, insertions: _, modifications: _):
                handler(collection).cauterize()
            case .error(let error):
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
            )
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

    public struct FetchDefinition {
        public var update: (
            _ api: HomeAssistantAPI,
            _ queue: DispatchQueue,
            _ modelManager: ModelManager
        ) -> Promise<Void>

        public static var defaults: [Self] = [
            .init(update: { api, queue, manager in
                api.GetZones().done(on: queue) { manager.store(type: RLMZone.self, sourceModels: $0) }
            }),
            .init(update: { api, queue, manager in
                api.GetStates()
                    .compactMapValues { $0 as? Scene }
                    .done(on: queue) { manager.store(type: RLMScene.self, sourceModels: $0) }
            })
        ]
    }

    public func fetch(
        definitions: [FetchDefinition] = FetchDefinition.defaults,
        on queue: DispatchQueue = .global(qos: .utility)
    ) -> Promise<Void> {
        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            return .value(())
        }

        return when(fulfilled: definitions.map { $0.update(api, queue, self) })
    }

    private func store<UM: Object & UpdatableModel>(
        type realmObjectType: UM.Type,
        sourceModels: [UM.Source]
    ) {
        let realm = Current.realm()

        do {
            try realm.write {
                guard let realmPrimaryKey = realmObjectType.primaryKey() else {
                    Current.Log.error("invalid realm object type: \(realmObjectType)")
                    return
                }

                let existingIDs = Set(realm.objects(UM.self).compactMap { $0[realmPrimaryKey] as? String })
                let incomingIDs = Set(sourceModels.map(\.primaryKey))

                let deletedIDs = existingIDs.subtracting(incomingIDs)
                let newIDs = incomingIDs.subtracting(existingIDs)

                Current.Log.verbose(
                    [
                        "updating \(UM.self)",
                        "from(\(existingIDs.count))",
                        "to(\(incomingIDs.count))",
                        "deleted(\(deletedIDs.count))",
                        "new(\(newIDs.count))"
                    ].joined(separator: " ")
                )

                let updatedModels: [UM] = sourceModels.map { model in
                    let updating: UM

                    if let existing = realm.object(ofType: UM.self, forPrimaryKey: model.primaryKey) {
                        updating = existing
                    } else {
                        Current.Log.verbose("creating \(model.primaryKey)")
                        updating = UM()
                    }

                    updating.update(with: model, using: realm)
                    return updating
                }

                realm.add(updatedModels, update: .all)
                realm.delete(realm.objects(UM.self).filter("%K in %@", realmPrimaryKey, deletedIDs))
                UM.didUpdate(objects: updatedModels)
            }
        } catch {
            Current.Log.error("failed to update \(UM.self): \(error)")
        }
    }
}
