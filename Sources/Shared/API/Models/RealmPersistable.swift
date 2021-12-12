import Foundation
import HAKit
import RealmSwift

protocol UpdatableModel {
    associatedtype Source: UpdatableModelSource

    static func didUpdate(objects: [Self], server: Server, realm: Realm)
    static func willDelete(objects: [Self], server: Server?, realm: Realm)

    static func primaryKey() -> String? // from realm, we use
    static func serverIdentifierKey() -> String
    static var updateEligiblePredicate: NSPredicate { get }

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String
    func update(with object: Source, server: Server, using realm: Realm) -> Bool
}

extension UpdatableModel {
    static var updateEligiblePredicate: NSPredicate { NSPredicate(value: true) }
}

protocol UpdatableModelSource {
    var primaryKey: String { get }
}

extension HAEntity: UpdatableModelSource {
    var primaryKey: String { entityId }
}
