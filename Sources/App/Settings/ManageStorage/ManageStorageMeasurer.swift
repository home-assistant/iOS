import Foundation
import GRDB
import Shared

/// Reports how much space a storage source currently occupies.
protocol ManageStorageMeasuring {
    func byteCount(of item: ManageStorageItem) async -> Int64
}

/// The real measurer: walks the file system, asks `URLCache` for its own usage, and adds up the
/// stored column values for database-backed rows.
///
/// Everything it touches is injected, so a test can point it at a temporary directory and assert on
/// byte counts it wrote itself.
struct ManageStorageMeasurer: ManageStorageMeasuring {
    let fileManager: FileManager
    let database: () -> DatabaseQueue
    let networkResponseCacheByteCount: () -> Int64

    init(
        fileManager: FileManager = .default,
        database: @escaping () -> DatabaseQueue = { Current.database() },
        networkResponseCacheByteCount: @escaping () -> Int64 = {
            Int64(URLCache.shared.currentDiskUsage) + Int64(URLCache.shared.currentMemoryUsage)
        }
    ) {
        self.fileManager = fileManager
        self.database = database
        self.networkResponseCacheByteCount = networkResponseCacheByteCount
    }

    func byteCount(of item: ManageStorageItem) async -> Int64 {
        switch item.source {
        case .files, .webKit:
            return byteCount(ofPaths: item.source.urls)
        case .networkResponseCache:
            return networkResponseCacheByteCount()
        case let .databaseTables(tables):
            return byteCount(ofTables: tables)
        }
    }

    private func byteCount(ofPaths urls: [URL]) -> Int64 {
        urls.reduce(into: Int64(0)) { total, url in
            total += byteCount(ofPath: url)
        }
    }

    private func byteCount(ofPath url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return 0 }

        guard isDirectory.boolValue else {
            return allocatedSize(of: url)
        }

        // No error handler: the default keeps walking past an unreadable subfolder, which is what
        // this wants — one locked folder should not cost the row the rest of its size.
        let children = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: Self.resourceKeys,
            options: []
        )?.allObjects ?? []

        var total: Int64 = 0
        for case let child as URL in children {
            total += allocatedSize(of: child)
        }
        return total
    }

    private static let resourceKeys: [URLResourceKey] = [
        .isRegularFileKey,
        .totalFileAllocatedSizeKey,
        .fileSizeKey,
    ]

    /// The space the file takes on disk, which is what freeing it would give back. Falls back to the
    /// logical size when the file system does not report an allocated size, and skips folders, whose
    /// own entry carries no bytes of its own.
    private func allocatedSize(of url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: Set(Self.resourceKeys)),
              values.isRegularFile != false else {
            return 0
        }
        return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
    }

    private func byteCount(ofTables tables: [String]) -> Int64 {
        do {
            return try database().read { db in
                try tables.reduce(into: Int64(0)) { total, table in
                    total += try Self.byteCount(ofTable: table, in: db)
                }
            }
        } catch {
            Current.Log.error("Failed to measure database tables \(tables): \(error)")
            return 0
        }
    }

    /// SQLite has no per-table size function that is available everywhere (`dbstat` is an optional
    /// build flag), so this sums the byte length of every stored value instead. That undercounts
    /// indexes and page overhead, which is why the database rows are reported as living inside the
    /// app database file rather than as standalone space.
    private static func byteCount(ofTable table: String, in db: Database) throws -> Int64 {
        guard try db.tableExists(table) else { return 0 }
        let columns = try db.columns(in: table).map(\.name)
        let lengths = columns
            .map { "LENGTH(COALESCE(CAST(\"\($0)\" AS BLOB), X''))" }
            .joined(separator: " + ")
        let sql = "SELECT COALESCE(SUM(\(lengths)), 0) FROM \"\(table)\""
        return try Int64.fetchOne(db, sql: sql) ?? 0
    }
}
