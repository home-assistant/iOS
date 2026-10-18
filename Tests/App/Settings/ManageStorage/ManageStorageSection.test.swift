@testable import HomeAssistant
import Testing

struct ManageStorageSectionTests {
    @Test func sectionSizeSkipsRowsCountedByAnotherRow() {
        let section = ManageStorageSection(category: .caches, items: [
            ManageStorageItem(
                id: .widgetCache,
                category: .caches,
                protection: .deletable,
                source: .files([]),
                byteCount: 100
            ),
            ManageStorageItem(
                id: .cachedEntities,
                category: .caches,
                protection: .deletable,
                source: .databaseTables(["hAAppEntity"]),
                countsTowardTotal: false,
                byteCount: 900
            ),
        ])

        #expect(section.byteCount == 100)
        #expect(section.formattedSize == ManageStorageItem.formatted(byteCount: 100))
        #expect(section.id == ManageStorageCategory.caches.rawValue)
    }

    @Test func anEmptySectionMeasuresZero() {
        let section = ManageStorageSection(category: .logs, items: [])

        #expect(section.byteCount == 0)
    }
}
