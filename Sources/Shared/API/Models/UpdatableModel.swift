import Foundation
import GRDB
import HAKit

/// A GRDB-backed model that can be diffed against a collection of source models
/// coming from a server (see `LegacyModelManager.store`).
protocol UpdatableModel: FetchableRecord, MutablePersistableRecord {
    associatedtype Source: UpdatableModelSource

    /// The column containing the server identifier the row belongs to.
    static var serverIdentifierColumnName: String { get }
    /// The column containing the primary key.
    static var primaryKeyColumnName: String { get }
    /// Only rows matching this condition take part in sync updates and
    /// deletions; `nil` means every row is eligible.
    static var updateEligibleCondition: SQLExpression? { get }

    static func primaryKey(sourceIdentifier: String, serverIdentifier: String) -> String

    var primaryKeyValue: String { get }

    /// Creates an empty model for the given primary key, to be filled in by
    /// `update(with:server:)`.
    init(primaryKey: String, serverIdentifier: String)

    /// Applies the source model. Returns false when the source is invalid and
    /// the model should not be persisted.
    mutating func update(with object: Source, server: Server) -> Bool
}

extension UpdatableModel {
    static var updateEligibleCondition: SQLExpression? { nil }
}

protocol UpdatableModelSource {
    var primaryKey: String { get }
}

extension HAEntity: UpdatableModelSource {
    var primaryKey: String { entityId }
}
