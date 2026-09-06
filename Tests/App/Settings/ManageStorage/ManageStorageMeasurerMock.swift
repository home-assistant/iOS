@testable import HomeAssistant

/// Hands back fixed sizes per item and records what it was asked to measure.
final class ManageStorageMeasurerMock: ManageStorageMeasuring, @unchecked Sendable {
    var byteCounts: [ManageStorageItemID: Int64]
    private(set) var measured: [ManageStorageItemID] = []

    init(byteCounts: [ManageStorageItemID: Int64] = [:]) {
        self.byteCounts = byteCounts
    }

    func byteCount(of item: ManageStorageItem) async -> Int64 {
        measured.append(item.id)
        return byteCounts[item.id] ?? 0
    }
}
