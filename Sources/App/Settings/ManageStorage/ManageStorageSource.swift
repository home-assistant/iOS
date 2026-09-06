import Foundation

/// Where a row's bytes physically live, and therefore how they are measured and freed.
enum ManageStorageSource: Equatable {
    /// Plain files and folders. Folders are measured recursively; deleting one empties it rather
    /// than removing the folder itself, because the app expects those folders to keep existing.
    case files([URL])
    /// Web content owned by `WKWebsiteDataStore`. WebKit exposes no size API, so the bytes are
    /// measured from the folders it writes to while deletion goes through the data store.
    case webKit(urls: [URL], dataTypes: Set<String>)
    /// `URLCache.shared`, which reports and clears its own disk usage.
    case networkResponseCache
    /// Rows inside the app database. Measured as the byte length of the stored column values, and
    /// deleted with `DELETE FROM`, followed by a `VACUUM` so the file on disk actually shrinks.
    case databaseTables([String])

    /// The folders and files this source occupies, if any. Used by the screen to show where a row
    /// lives, and by the measurer for everything that is not `URLCache` or the database.
    var urls: [URL] {
        switch self {
        case let .files(urls):
            return urls
        case let .webKit(urls, _):
            return urls
        case .networkResponseCache, .databaseTables:
            return []
        }
    }
}
