import Foundation
import RealmSwift

protocol UpdatableModel {
    associatedtype Source: UpdatableModelSource

    static func didUpdate(objects: [Self], realm: Realm)
    static func willDelete(objects: [Self], realm: Realm)

    static func primaryKey() -> String? // from realm, we use
    static var updateEligiblePredicate: NSPredicate { get }
    func update(with object: Source, using realm: Realm)
}

extension UpdatableModel {
    static var updateEligiblePredicate: NSPredicate { NSPredicate(value: true) }
}

protocol UpdatableModelSource {
    var primaryKey: String { get }
}

extension Entity: UpdatableModelSource {
    var primaryKey: String { ID }
}
