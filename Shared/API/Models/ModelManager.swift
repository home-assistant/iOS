import Foundation
import RealmSwift
import PromiseKit

public final class ModelManager {
    public struct CleanupDefinition {
        var model: Object.Type
        var createdKey: String
        var duration: Measurement<UnitDuration>

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

    public static func cleanup(
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
                            cleanup(using: definition, realm: realm)
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

    private static func cleanup(
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
}
