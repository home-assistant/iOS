import Foundation
import GRDB

/// A single SQLite value in a portable, Codable form, so GRDB rows can be serialized
/// into an iCloud snapshot on one device and rebuilt on another.
public enum CloudSyncValue: Codable, Equatable {
    case null
    case integer(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    init(databaseValue: DatabaseValue) {
        switch databaseValue.storage {
        case .null:
            self = .null
        case let .int64(value):
            self = .integer(value)
        case let .double(value):
            self = .double(value)
        case let .string(value):
            self = .text(value)
        case let .blob(value):
            self = .blob(value)
        }
    }

    var databaseValue: DatabaseValue {
        switch self {
        case .null:
            return .null
        case let .integer(value):
            return value.databaseValue
        case let .double(value):
            return value.databaseValue
        case let .text(value):
            return value.databaseValue
        case let .blob(value):
            return value.databaseValue
        }
    }
}
