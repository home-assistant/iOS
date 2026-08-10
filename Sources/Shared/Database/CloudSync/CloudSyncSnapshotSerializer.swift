import Foundation
import GRDB

public final class CloudSyncSnapshotSerializer: CloudSyncSnapshotSerializerProtocol {
    public init() {}

    public func exportSnapshot() throws -> CloudSyncSnapshot {
        let database = Current.database()
        var tables: [String: [[String: CloudSyncValue]]] = [:]

        try database.read { db in
            for table in DatabaseQueue.tables() {
                guard try db.tableExists(table.tableName) else { continue }
                let rows = try Row.fetchAll(db, sql: "SELECT * FROM \(table.tableName)")
                tables[table.tableName] = rows.map { row in
                    Dictionary(uniqueKeysWithValues: zip(row.columnNames, row.databaseValues).map { column, value in
                        (column, CloudSyncValue(databaseValue: value))
                    })
                }
            }
        }

        return CloudSyncSnapshot(
            createdAt: Current.date(),
            sourceDeviceID: Current.device.identifierForVendor() ?? "unknown",
            tables: tables
        )
    }

    public func importSnapshot(_ snapshot: CloudSyncSnapshot) throws {
        guard snapshot.formatVersion <= CloudSyncSnapshot.currentFormatVersion else {
            throw CloudSyncSnapshotError.incompatibleFormatVersion(snapshot.formatVersion)
        }

        let database = Current.database()
        try database.write { db in
            for table in DatabaseQueue.tables() {
                let tableName = table.tableName
                // A table missing from the snapshot means the writing device didn't know
                // it (older app version); leave the local rows alone. An empty array
                // means the table really was empty, so the local rows are cleared.
                guard let rows = snapshot.tables[tableName], try db.tableExists(tableName) else { continue }

                let localColumns = try Set(db.columns(in: tableName).map(\.name))
                try db.execute(sql: "DELETE FROM \(tableName)")

                for row in rows {
                    let columns = row.keys.filter { localColumns.contains($0) }.sorted()
                    guard !columns.isEmpty else { continue }

                    let columnList = columns.map { "\"\($0)\"" }.joined(separator: ", ")
                    let placeholders = Array(repeating: "?", count: columns.count).joined(separator: ", ")
                    let values = columns.map { row[$0]?.databaseValue ?? .null }
                    try db.execute(
                        sql: "INSERT INTO \(tableName) (\(columnList)) VALUES (\(placeholders))",
                        arguments: StatementArguments(values)
                    )
                }
            }
        }
    }
}
