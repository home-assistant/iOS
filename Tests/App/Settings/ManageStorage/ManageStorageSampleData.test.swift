@testable import HomeAssistant
import Testing

struct ManageStorageSampleDataTests {
    @Test func theSampleMeasurerHasASizeForEveryRow() async {
        let measurer = ManageStorageSampleMeasurer()

        for id in ManageStorageItemID.allCases {
            #expect(ManageStorageSampleMeasurer.byteCounts[id] != nil, "missing sample size for \(id.rawValue)")
            let item = ManageStorageItem(
                id: id,
                category: .caches,
                protection: .deletable,
                source: .files([])
            )
            let measured = await measurer.byteCount(of: item)
            #expect(measured == ManageStorageSampleMeasurer.byteCounts[id])
        }
    }

    @Test func theSampleCleanerNeverTouchesRealStorage() async throws {
        let item = ManageStorageItem(
            id: .logFiles,
            category: .logs,
            protection: .deletable,
            source: .files([])
        )

        try await ManageStorageSampleCleaner().clean(item)
    }
}
