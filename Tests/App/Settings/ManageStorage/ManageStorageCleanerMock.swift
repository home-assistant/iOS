import Foundation
@testable import HomeAssistant

/// Records what the view model asked to clean, and can fail on demand.
final class ManageStorageCleanerMock: ManageStorageCleaning, @unchecked Sendable {
    struct Failure: LocalizedError {
        var errorDescription: String? { "cleaning failed" }
    }

    var errorToThrow: Error?
    private(set) var cleaned: [ManageStorageItemID] = []

    func clean(_ item: ManageStorageItem) async throws {
        cleaned.append(item.id)
        if let errorToThrow {
            throw errorToThrow
        }
    }
}
