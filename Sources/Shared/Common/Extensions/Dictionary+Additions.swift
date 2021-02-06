import Foundation

public extension Dictionary {
    func mapKeys<T>(_ transform: (Key) throws -> T) rethrows -> [T: Value] {
        try reduce(into: [T: Value]()) { result, element in
            result[try transform(element.key)] = element.value
        }
    }

    func compactMapKeys<T>(_ transform: (Key) throws -> T?) rethrows -> [T: Value] {
        try reduce(into: [T: Value]()) { result, element in
            if let newKey = try transform(element.key) {
                result[newKey] = element.value
            }
        }
    }
}
