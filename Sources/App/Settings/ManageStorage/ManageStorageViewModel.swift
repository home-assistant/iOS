import Combine
import Foundation
import Shared

@MainActor
final class ManageStorageViewModel: ObservableObject {
    @Published private(set) var items: [ManageStorageItem]
    @Published private(set) var isLoading = false
    /// The row currently being emptied, so its spinner replaces its size.
    @Published private(set) var cleaningItemID: ManageStorageItemID?
    @Published var filter = ManageStorageFilter()
    @Published var sortOrder: ManageStorageSortOrder = .largestFirst
    @Published var itemPendingCleaning: ManageStorageItem?
    @Published var errorMessage: String?

    private let measurer: ManageStorageMeasuring
    private let cleaner: ManageStorageCleaning

    init(
        paths: ManageStoragePaths = .live,
        isCatalyst: Bool = Current.isCatalyst,
        hasCompletedLegacyStoreMigration: Bool = RealmToGRDBMigration.hasCompletedMigration,
        measurer: ManageStorageMeasuring = ManageStorageMeasurer(),
        cleaner: ManageStorageCleaning = ManageStorageCleaner()
    ) {
        self.items = ManageStorageInventory.items(
            paths: paths,
            isCatalyst: isCatalyst,
            hasCompletedLegacyStoreMigration: hasCompletedLegacyStoreMigration
        )
        self.measurer = measurer
        self.cleaner = cleaner
    }

    var visibleItems: [ManageStorageItem] {
        sortOrder.sort(filter.apply(to: items))
    }

    /// The visible rows grouped into the sections the list draws, empty categories dropped.
    var sections: [ManageStorageSection] {
        let grouped = Dictionary(grouping: visibleItems, by: \.category)
        let built = grouped.map { category, rows in
            ManageStorageSection(category: category, items: sortOrder.sort(rows))
        }
        return sortOrder.sort(built)
    }

    /// Categories that actually have a row, so the filter menu never offers an empty result.
    var availableCategories: [ManageStorageCategory] {
        ManageStorageCategory.allCases.filter { category in
            items.contains { $0.category == category }
        }
    }

    /// What the app occupies in total. Rows living inside another row's file are left out so the
    /// database is not counted twice.
    var totalByteCount: Int64 {
        items.filter(\.countsTowardTotal).reduce(into: Int64(0)) { $0 += $1.byteCount }
    }

    /// What this screen could free right now.
    var reclaimableByteCount: Int64 {
        items.filter(\.isDeletable).reduce(into: Int64(0)) { $0 += $1.byteCount }
    }

    var protectedItemCount: Int {
        items.filter { !$0.isDeletable }.count
    }

    func load() async {
        // Pull to refresh and the first appearance can both start a load. Two passes would race:
        // the first to finish would clear `isLoading` while the other was still measuring, and the
        // last to finish would overwrite `items` with whichever sizes it happened to hold.
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        var measured = items
        for index in measured.indices {
            measured[index].byteCount = await measurer.byteCount(of: measured[index])
        }
        items = measured
    }

    /// Asks for confirmation rather than deleting straight away — every row here is cheap to lose
    /// but none of it comes back without a round trip to the server or a rebuild.
    func confirmCleaning(of item: ManageStorageItem) {
        guard item.isDeletable else {
            errorMessage = item.protection.reason?.explanation
            return
        }
        itemPendingCleaning = item
    }

    func clean(_ item: ManageStorageItem) async {
        guard item.isDeletable else {
            // The UI disables these rows; reaching here means the inventory and the screen disagree.
            Current.Log.error("Refused to clean protected storage item \(item.id.rawValue)")
            errorMessage = item.protection.reason?.explanation
            return
        }

        cleaningItemID = item.id
        do {
            try await cleaner.clean(item)
            Current.Log.info("Cleaned storage item \(item.id.rawValue)")
        } catch {
            Current.Log.error("Failed to clean storage item \(item.id.rawValue): \(error)")
            errorMessage = error.localizedDescription
        }
        await remeasure(item)
        cleaningItemID = nil
    }

    /// Rebuilds the list rather than writing through an index: a concurrent `load()` can have
    /// replaced the array while the clean was running.
    private func remeasure(_ item: ManageStorageItem) async {
        let byteCount = await measurer.byteCount(of: item)
        items = items.map { current in
            guard current.id == item.id else { return current }
            var updated = current
            updated.byteCount = byteCount
            return updated
        }
    }
}
