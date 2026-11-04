@testable import HomeAssistant
import Testing

struct ManageStorageSortOrderTests {
    private func item(_ id: ManageStorageItemID, byteCount: Int64) -> ManageStorageItem {
        ManageStorageItem(
            id: id,
            category: id == .widgetCache ? .caches : .logs,
            protection: .deletable,
            source: .files([]),
            byteCount: byteCount
        )
    }

    private var items: [ManageStorageItem] {
        [
            item(.logFiles, byteCount: 10),
            item(.widgetCache, byteCount: 300),
            item(.clientEventLog, byteCount: 200),
        ]
    }

    @Test func everySortOrderIsNamed() {
        for order in ManageStorageSortOrder.allCases {
            #expect(!order.title.isEmpty, "missing title for \(order.rawValue)")
            #expect(order.id == order.rawValue)
        }
    }

    @Test func sizeSortsRunBothWays() {
        #expect(ManageStorageSortOrder.largestFirst.sort(items).map(\.byteCount) == [300, 200, 10])
        #expect(ManageStorageSortOrder.smallestFirst.sort(items).map(\.byteCount) == [10, 200, 300])
    }

    @Test func nameSortIsAlphabeticalRegardlessOfSize() {
        let sorted = ManageStorageSortOrder.name.sort(items)
        let alphabetical = items.map(\.title).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        #expect(sorted.map(\.title) == alphabetical)
    }

    @Test func rowsOfTheSameSizeKeepAStableAlphabeticalOrder() {
        let tied = [item(.widgetCache, byteCount: 5), item(.clientEventLog, byteCount: 5)]

        let largest = ManageStorageSortOrder.largestFirst.sort(tied).map(\.title)
        let smallest = ManageStorageSortOrder.smallestFirst.sort(tied).map(\.title)

        let alphabetical = tied.map(\.title).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        #expect(largest == smallest)
        #expect(largest == alphabetical)
    }

    @Test func sectionsFollowTheSameOrderAsRows() {
        let sections = [
            ManageStorageSection(category: .logs, items: [item(.logFiles, byteCount: 10)]),
            ManageStorageSection(category: .caches, items: [item(.widgetCache, byteCount: 300)]),
        ]

        #expect(ManageStorageSortOrder.largestFirst.sort(sections).map(\.category) == [.caches, .logs])
        #expect(ManageStorageSortOrder.smallestFirst.sort(sections).map(\.category) == [.logs, .caches])
        #expect(ManageStorageSortOrder.name.sort(sections).map(\.category) == [.caches, .logs])
    }

    @Test func sectionsOfEqualSizeFallBackToTheCategoryOrder() {
        let sections = [
            ManageStorageSection(category: .logs, items: []),
            ManageStorageSection(category: .caches, items: []),
        ]

        for order in ManageStorageSortOrder.allCases {
            #expect(order.sort(sections).map(\.category) == [.caches, .logs], "\(order.rawValue)")
        }
    }
}
