@testable import HomeAssistant

/// Hands back fixed sizes per item and records what it was asked to measure.
final class ManageStorageMeasurerMock: ManageStorageMeasuring, @unchecked Sendable {
    var byteCounts: [ManageStorageItemID: Int64]
    /// Runs once, part way through a measurement pass, so a test can re-enter the view model while
    /// a load is still in flight.
    var duringFirstMeasurement: (() async -> Void)?
    private(set) var measured: [ManageStorageItemID] = []

    init(byteCounts: [ManageStorageItemID: Int64] = [:]) {
        self.byteCounts = byteCounts
    }

    func byteCount(of item: ManageStorageItem) async -> Int64 {
        measured.append(item.id)
        if let hook = duringFirstMeasurement {
            duringFirstMeasurement = nil
            await hook()
        }
        return byteCounts[item.id] ?? 0
    }
}
