import Foundation
import GRDB
@testable import HomeAssistant
import Testing

struct ManageStorageCleanerTests {
    private func makeTemporaryDirectory() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("manage-storage-cleaner-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(contents.utf8).write(to: url)
    }

    private func item(source: ManageStorageSource) -> ManageStorageItem {
        ManageStorageItem(id: .logFiles, category: .logs, protection: .deletable, source: source)
    }

    private func makeCleaner(
        cleanWebsiteData: @escaping (Set<String>) async -> Void = { _ in },
        clearNetworkResponseCache: @escaping () -> Void = {}
    ) -> ManageStorageCleaner {
        ManageStorageCleaner(
            database: { fatalError("the database should not be opened for a file-backed row") },
            cleanWebsiteData: cleanWebsiteData,
            clearNetworkResponseCache: clearNetworkResponseCache
        )
    }

    @Test func aFolderIsEmptiedButKept() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try write("a", to: root.appendingPathComponent("a.log"))
        try write("b", to: root.appendingPathComponent("nested/b.log"))

        try await makeCleaner().clean(item(source: .files([root])))

        let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(remaining.isEmpty)
    }

    @Test func aSingleFileIsRemoved() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("only.log")
        try write("a", to: file)

        try await makeCleaner().clean(item(source: .files([file])))

        #expect(!FileManager.default.fileExists(atPath: file.path))
        #expect(FileManager.default.fileExists(atPath: root.path))
    }

    @Test func aPathThatIsNotThereIsLeftAlone() async throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("manage-storage-missing-\(UUID().uuidString)")

        try await makeCleaner().clean(item(source: .files([missing])))

        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    @Test func webContentIsClearedThroughTheWebsiteDataStore() async throws {
        let requested = ManageStorageTestBox<Set<String>?>(nil)
        let subject = makeCleaner(cleanWebsiteData: { dataTypes in
            requested.value = dataTypes
        })

        try await subject.clean(item(source: .webKit(urls: [], dataTypes: ["cache", "cookies"])))

        #expect(requested.value == ["cache", "cookies"])
    }

    @Test func theNetworkResponseCacheIsClearedThroughUrlCache() async throws {
        let cleared = ManageStorageTestBox(false)
        let subject = makeCleaner(clearNetworkResponseCache: { cleared.value = true })

        try await subject.clean(item(source: .networkResponseCache))

        #expect(cleared.value)
    }

    @Test func databaseRowsAreDeletedAndTheFileIsCompacted() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let queue = try DatabaseQueue(path: root.appendingPathComponent("test.sqlite").path)
        try queue.write { db in
            try db.execute(sql: "CREATE TABLE sample (id TEXT)")
            try db.execute(sql: "CREATE TABLE keep (id TEXT)")
            try db.execute(sql: "INSERT INTO sample VALUES ('a')")
            try db.execute(sql: "INSERT INTO keep VALUES ('b')")
        }
        let subject = ManageStorageCleaner(
            database: { queue },
            cleanWebsiteData: { _ in },
            clearNetworkResponseCache: {}
        )

        try await subject.clean(item(source: .databaseTables(["sample", "not_a_table"])))

        let counts = try queue.read { db in
            try (
                Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sample") ?? -1,
                Int.fetchOne(db, sql: "SELECT COUNT(*) FROM keep") ?? -1
            )
        }
        #expect(counts.0 == 0)
        #expect(counts.1 == 1, "other tables are left alone")
    }
}
