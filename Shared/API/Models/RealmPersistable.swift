import Foundation
import RealmSwift

protocol UpdatableModel {
    associatedtype Source: UpdatableModelSource
    static func didUpdate(objects: [Self])
    static func primaryKey() -> String? // from realm, we use
    func update(with object: Source, using realm: Realm)
}

protocol UpdatableModelSource {
    var primaryKey: String { get }
}

extension Entity: UpdatableModelSource {
    var primaryKey: String { ID }
}
