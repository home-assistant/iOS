import Foundation
import PromiseKit
import RealmSwift

public struct ClientEventStore {
    public var addEvent: (ClientEvent) -> Promise<Void> = { event in
        let realm = Current.realm()
        Current.Log.info("\(event.type): \(event.text) \(event.jsonPayload ?? [:])")
        return realm.reentrantWrite {
            realm.add(event)
        }
    }

    public func getEvents(filter: String? = nil) -> AnyRealmCollection<ClientEvent> {
        let realm = Current.realm()
        let objects = realm.objects(ClientEvent.self).sorted(byKeyPath: "date", ascending: false)
        if let filter = filter, filter.isEmpty == false {
            return AnyRealmCollection(objects.filter(NSPredicate(format: "text contains[c] %@", filter)))
        } else {
            return AnyRealmCollection(objects)
        }
    }

    public var clearAllEvents: () -> Promise<Void> = {
        let realm = Current.realm()
        return realm.reentrantWrite {
            realm.delete(realm.objects(ClientEvent.self))
        }
    }
}
