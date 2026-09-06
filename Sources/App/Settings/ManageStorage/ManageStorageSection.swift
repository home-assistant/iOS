import Foundation

/// One category's worth of rows, as the list renders it.
struct ManageStorageSection: Identifiable, Equatable {
    let category: ManageStorageCategory
    let items: [ManageStorageItem]

    var id: String { category.rawValue }

    /// Only rows that carry their own bytes count here, matching the grand total: the rows stored
    /// inside the app database would otherwise be added on top of the database file that holds them.
    var byteCount: Int64 {
        items.filter(\.countsTowardTotal).reduce(into: Int64(0)) { $0 += $1.byteCount }
    }

    var formattedSize: String {
        ManageStorageItem.formatted(byteCount: byteCount)
    }
}
