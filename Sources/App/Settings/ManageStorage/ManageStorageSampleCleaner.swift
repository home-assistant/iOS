import Foundation

/// A cleaner that does nothing, so the SwiftUI preview and the snapshot tests cannot delete the
/// simulator's real caches when a delete button is exercised.
struct ManageStorageSampleCleaner: ManageStorageCleaning {
    func clean(_ item: ManageStorageItem) async throws {}
}
