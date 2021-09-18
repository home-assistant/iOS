// swiftlint:disable all

import Foundation
import ObjectMapper
import RealmSwift

infix operator <-

/// Object of Realm's List type
public func <- <T: Mappable>(left: List<T>, right: Map) {
    var array: [T]?

    if right.mappingType == .toJSON {
        array = Array(left)
    }

    array <- right

    if right.mappingType == .fromJSON {
        if let theArray = array {
            left.append(objectsIn: theArray)
        }
    }
}

/// Object of Realm's RealmOptional type
public func <- <T>(left: RealmProperty<T?>, right: Map) {
    var optional: T?

    if right.mappingType == .toJSON {
        optional = left.value
    }

    optional <- right

    if right.mappingType == .fromJSON {
        if let theOptional = optional {
            left.value = theOptional
        }
    }
}
