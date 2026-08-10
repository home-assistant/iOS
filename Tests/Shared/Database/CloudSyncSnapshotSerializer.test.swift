import Foundation
import GRDB
@testable import Shared
import Testing

@Suite(.serialized)
struct CloudSyncSnapshotSerializerTests {
    @Test("Snapshot round-trips: export, wipe, import restores rows")
    func roundTrip() throws {
        try withCloudSyncDatabase {
            AllowedTag.add("garage")
            AllowedTag.add("front-door")

            let serializer = CloudSyncSnapshotSerializer()
            let snapshot = try serializer.exportSnapshot()
            #expect(snapshot.tables[GRDBDatabaseTable.allowedTags.rawValue]?.count == 2)

            try Current.database().eraseAllData()
            #expect(AllowedTag.all().isEmpty)

            try serializer.importSnapshot(snapshot)
            #expect(AllowedTag.all().map(\.tag) == ["front-door", "garage"])
        }
    }

    @Test("Import ignores unknown tables and columns from newer app versions")
    func importIgnoresUnknownTablesAndColumns() throws {
        try withCloudSyncDatabase {
            let snapshot = CloudSyncSnapshot(
                createdAt: Date(timeIntervalSince1970: 0),
                sourceDeviceID: "other-device",
                tables: [
                    "notARealTable": [["id": .text("1")]],
                    GRDBDatabaseTable.allowedTags.rawValue: [
                        ["tag": .text("garage"), "bogusColumn": .integer(1)],
                    ],
                ]
            )

            try CloudSyncSnapshotSerializer().importSnapshot(snapshot)

            #expect(AllowedTag.all().map(\.tag) == ["garage"])
        }
    }

    @Test("Importing an empty table clears the local rows")
    func importEmptyTableClearsLocalRows() throws {
        try withCloudSyncDatabase {
            AllowedTag.add("garage")

            let snapshot = CloudSyncSnapshot(
                createdAt: Date(timeIntervalSince1970: 0),
                sourceDeviceID: "other-device",
                tables: [GRDBDatabaseTable.allowedTags.rawValue: []]
            )

            try CloudSyncSnapshotSerializer().importSnapshot(snapshot)

            #expect(AllowedTag.all().isEmpty)
        }
    }

    @Test("A table missing from the snapshot leaves local rows untouched")
    func importMissingTableKeepsLocalRows() throws {
        try withCloudSyncDatabase {
            AllowedTag.add("garage")

            let snapshot = CloudSyncSnapshot(
                createdAt: Date(timeIntervalSince1970: 0),
                sourceDeviceID: "other-device",
                tables: [:]
            )

            try CloudSyncSnapshotSerializer().importSnapshot(snapshot)

            #expect(AllowedTag.all().map(\.tag) == ["garage"])
        }
    }

    @Test("Snapshots from newer format versions are refused")
    func importRefusesNewerFormatVersions() throws {
        try withCloudSyncDatabase {
            let snapshot = CloudSyncSnapshot(
                formatVersion: CloudSyncSnapshot.currentFormatVersion + 1,
                createdAt: Date(timeIntervalSince1970: 0),
                sourceDeviceID: "other-device",
                tables: [:]
            )

            #expect(throws: CloudSyncSnapshotError.self) {
                try CloudSyncSnapshotSerializer().importSnapshot(snapshot)
            }
        }
    }

    @Test("Content hash ignores metadata and ordering but tracks data changes")
    func contentHashStability() throws {
        let rowA: [String: CloudSyncValue] = ["id": .text("1"), "value": .integer(5)]
        let rowB: [String: CloudSyncValue] = [
            "id": .text("2"),
            "value": .double(1.5),
            "data": .blob(Data([1, 2])),
            "note": .null,
        ]

        let first = CloudSyncSnapshot(
            createdAt: Date(timeIntervalSince1970: 0),
            sourceDeviceID: "a",
            tables: ["table": [rowA, rowB]]
        )
        let second = CloudSyncSnapshot(
            createdAt: Date(timeIntervalSince1970: 100),
            sourceDeviceID: "b",
            tables: ["table": [rowB, rowA]]
        )

        #expect(first.contentHash == second.contentHash)

        var changed = first
        changed.tables["table"] = [rowA]
        #expect(changed.contentHash != first.contentHash)
    }

    @Test("Snapshots survive JSON encoding and decoding")
    func codableRoundTrip() throws {
        let snapshot = CloudSyncSnapshot(
            createdAt: Date(timeIntervalSince1970: 42),
            sourceDeviceID: "device",
            tables: [
                "table": [[
                    "text": .text("value"),
                    "int": .integer(7),
                    "double": .double(2.25),
                    "blob": .blob(Data([9, 8, 7])),
                    "null": .null,
                ]],
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(CloudSyncSnapshot.self, from: encoder.encode(snapshot))

        #expect(decoded == snapshot)
        #expect(decoded.contentHash == snapshot.contentHash)
    }

    private func withCloudSyncDatabase(perform work: () throws -> Void) throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")

        // AllowedTagTable's createIfNeeded migrates legacy UserDefaults tags; make sure
        // leftovers from other suites can't leak rows into these tests.
        Current.settingsStore.prefs.removeObject(forKey: "allowedTags")

        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }

        defer {
            Current.database = previousDatabase
        }

        try work()
    }
}
