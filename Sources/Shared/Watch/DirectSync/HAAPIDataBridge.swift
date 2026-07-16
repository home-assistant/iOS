#if os(watchOS)
import Foundation
import HAAPI
import HAKit

/// Decodes untyped HAAPI results with the app's existing HAKit models
/// (`HADataDecodable`), giving exact parity with the iPhone's parsing pipeline without
/// duplicating any model.
enum HAAPIDataBridge {
    static func decode<T: HADataDecodable>(_ type: T.Type, from value: HAAPIJSONValue) throws -> T {
        try T(data: HAData(value: value.anyValue))
    }

    static func decodeArray<T: HADataDecodable>(_ type: T.Type, from value: HAAPIJSONValue) throws -> [T] {
        guard let array = value.arrayValue else {
            throw WatchDirectSyncError.unexpectedPayload(String(describing: T.self))
        }
        return try array.map { try T(data: HAData(value: $0.anyValue)) }
    }

    /// Lenient array decode: elements that fail to decode are dropped (and identified in the log)
    /// instead of failing the whole payload — one malformed entity must not abort a full sync.
    static func decodeArrayLeniently<T: HADataDecodable>(_ type: T.Type, from value: HAAPIJSONValue) -> [T] {
        guard let array = value.arrayValue else { return [] }
        var decoded: [T] = []
        decoded.reserveCapacity(array.count)
        var droppedIds: [String] = []
        for element in array {
            if let item = try? T(data: HAData(value: element.anyValue)) {
                decoded.append(item)
            } else {
                droppedIds.append(element.objectValue?["entity_id"]?.stringValue ?? "<no entity_id>")
            }
        }
        if !droppedIds.isEmpty {
            Current.Log.error(
                "Dropped \(droppedIds.count)/\(array.count) \(String(describing: T.self)) rows that failed to decode: "
                    + droppedIds.prefix(30).joined(separator: ", ")
            )
        }
        return decoded
    }
}
#endif
