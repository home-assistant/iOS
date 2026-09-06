import Foundation
import GRDB
import Shared

/// Frees the space a storage source occupies.
protocol ManageStorageCleaning {
    func clean(_ item: ManageStorageItem) async throws
}

/// The real cleaner. It only ever runs against a source the inventory marked deletable — the view
/// model refuses protected rows before it gets here — so it does not second-guess what it is given.
struct ManageStorageCleaner: ManageStorageCleaning {
    let fileManager: FileManager
    let database: () -> DatabaseQueue
    let cleanWebsiteData: (Set<String>) async -> Void
    let clearNetworkResponseCache: () -> Void

    init(
        fileManager: FileManager = .default,
        database: @escaping () -> DatabaseQueue = { Current.database() },
        cleanWebsiteData: @escaping (Set<String>) async -> Void = { dataTypes in
            await withCheckedContinuation { continuation in
                Current.websiteDataStoreHandler.cleanCache(dataTypes: dataTypes) {
                    continuation.resume()
                }
            }
        },
        clearNetworkResponseCache: @escaping () -> Void = { URLCache.shared.removeAllCachedResponses() }
    ) {
        self.fileManager = fileManager
        self.database = database
        self.cleanWebsiteData = cleanWebsiteData
        self.clearNetworkResponseCache = clearNetworkResponseCache
    }

    func clean(_ item: ManageStorageItem) async throws {
        switch item.source {
        case let .files(urls):
            try removeContents(of: urls)
        case let .webKit(_, dataTypes):
            await cleanWebsiteData(dataTypes)
        case .networkResponseCache:
            clearNetworkResponseCache()
        case let .databaseTables(tables):
            try emptyTables(tables)
        }
    }

    /// Empties folders instead of deleting them: the app creates these folders once and then writes
    /// into them from extensions too, so removing the folder itself would break the next write.
    private func removeContents(of urls: [URL]) throws {
        for url in urls {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }

            if isDirectory.boolValue {
                let children = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                for child in children {
                    try fileManager.removeItem(at: child)
                }
            } else {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func emptyTables(_ tables: [String]) throws {
        let queue = database()
        try queue.write { db in
            for table in tables {
                guard try db.tableExists(table) else { continue }
                try db.execute(sql: "DELETE FROM \"\(table)\"")
            }
        }
        // Deleting rows leaves the pages behind as free space inside the file, so without this the
        // screen would report the same size right after a successful delete.
        try queue.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM")
        }
    }
}
