import Foundation
import GRDB
@testable import HomeAssistant
import Testing

struct ManageStorageMeasurerTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("manage-storage-measurer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ byteCount: Int, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(repeating: 0x41, count: byteCount).write(to: url)
    }

    private func item(source: ManageStorageSource) -> ManageStorageItem {
        ManageStorageItem(id: .logFiles, category: .logs, protection: .deletable, source: source)
    }

    private func makeMeasurer(networkResponseCacheByteCount: Int64 = 0) -> ManageStorageMeasurer {
        ManageStorageMeasurer(
            database: { fatalError("the database should not be opened for a file-backed row") },
            networkResponseCacheByteCount: { networkResponseCacheByteCount }
        )
    }

    @Test func aFolderIsMeasuredRecursively() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(4096, to: root.appendingPathComponent("a.log"))
        try write(4096, to: root.appendingPathComponent("nested/b.log"))

        let measured = await makeMeasurer().byteCount(of: item(source: .files([root])))

        #expect(measured >= 8192)
    }

    @Test func aSingleFileIsMeasuredOnItsOwn() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("only.log")
        try write(4096, to: file)

        let measured = await makeMeasurer().byteCount(of: item(source: .files([file])))

        #expect(measured >= 4096)
    }

    @Test func severalPathsAddUp() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first.log")
        let second = root.appendingPathComponent("second.log")
        try write(4096, to: first)
        try write(4096, to: second)

        let both = await makeMeasurer().byteCount(of: item(source: .files([first, second])))
        let one = await makeMeasurer().byteCount(of: item(source: .files([first])))

        #expect(both == one * 2)
    }

    @Test func aPathThatIsNotThereMeasuresZero() async throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("manage-storage-missing-\(UUID().uuidString)")

        let measured = await makeMeasurer().byteCount(of: item(source: .files([missing])))

        #expect(measured == 0)
    }

    @Test func anEmptyFolderMeasuresZero() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }

        let measured = await makeMeasurer().byteCount(of: item(source: .files([root])))

        #expect(measured == 0)
    }

    @Test func webKitRowsAreMeasuredFromTheFoldersWebKitWritesTo() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write(4096, to: root.appendingPathComponent("cache.bin"))

        let measured = await makeMeasurer().byteCount(
            of: item(source: .webKit(urls: [root], dataTypes: ["anything"]))
        )

        #expect(measured >= 4096)
    }

    @Test func theNetworkResponseCacheReportsItsOwnUsage() async throws {
        let measured = await makeMeasurer(networkResponseCacheByteCount: 1234)
            .byteCount(of: item(source: .networkResponseCache))

        #expect(measured == 1234)
    }

    @Test func databaseRowsAreMeasuredFromTheirStoredValues() async throws {
        let queue = try DatabaseQueue()
        try await queue.write { db in
            try db.execute(sql: "CREATE TABLE sample (id TEXT, payload TEXT)")
            try db.execute(sql: "INSERT INTO sample VALUES ('ab', 'cdef')")
            try db.execute(sql: "INSERT INTO sample VALUES ('gh', NULL)")
        }
        let subject = ManageStorageMeasurer(
            database: { queue },
            networkResponseCacheByteCount: { 0 }
        )

        let measured = await subject.byteCount(of: item(source: .databaseTables(["sample"])))

        #expect(measured == 8)
    }

    @Test func anEmptyOrMissingTableMeasuresZero() async throws {
        let queue = try DatabaseQueue()
        try await queue.write { db in
            try db.execute(sql: "CREATE TABLE sample (id TEXT)")
        }
        let subject = ManageStorageMeasurer(
            database: { queue },
            networkResponseCacheByteCount: { 0 }
        )

        let empty = await subject.byteCount(of: item(source: .databaseTables(["sample"])))
        let missing = await subject.byteCount(of: item(source: .databaseTables(["not_a_table"])))

        #expect(empty == 0)
        #expect(missing == 0)
    }

    @Test func aTableThatCannotBeQueriedMeasuresZeroInsteadOfFailing() async throws {
        let queue = try DatabaseQueue()
        // A column name carrying a quote breaks the generated length query, which is the closest
        // stand-in for the real failure: a database the app cannot read right now.
        try await queue.write { db in
            try db.execute(sql: "CREATE TABLE weird (\"x\"\"y\" TEXT)")
            try db.execute(sql: "INSERT INTO weird VALUES ('value')")
        }
        let subject = ManageStorageMeasurer(
            database: { queue },
            networkResponseCacheByteCount: { 0 }
        )

        let measured = await subject.byteCount(of: item(source: .databaseTables(["weird"])))

        #expect(measured == 0)
    }
}
