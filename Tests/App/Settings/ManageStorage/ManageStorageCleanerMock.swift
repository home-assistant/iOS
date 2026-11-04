import Foundation
@testable import HomeAssistant

/// Records what the view model asked to clean, and can fail on demand.
final class ManageStorageCleanerMock: ManageStorageCleaning, @unchecked Sendable {
    struct Failure: LocalizedError {
        var errorDescription: String? { "cleaning failed" }
    }

    var errorToThrow: Error?
    /// Runs while a clean is in flight, so a test can re-enter the view model mid-delete.
    var duringClean: (() async -> Void)?
    private(set) var cleaned: [ManageStorageItemID] = []

    func clean(_ item: ManageStorageItem) async throws {
        cleaned.append(item.id)
        if let hook = duringClean {
            duringClean = nil
            await hook()
        }
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
