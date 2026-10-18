import Foundation

/// One row on the "Manage Storage" screen: what it is, which bucket it belongs to, whether it can
/// be deleted, and how big it currently is.
struct ManageStorageItem: Identifiable, Equatable {
    let id: ManageStorageItemID
    let category: ManageStorageCategory
    let protection: ManageStorageProtection
    let source: ManageStorageSource
    /// `false` when these bytes are already counted by another row — the database-backed rows live
    /// inside `appDatabase`'s file, so counting them again would inflate the total.
    let countsTowardTotal: Bool
    var byteCount: Int64

    init(
        id: ManageStorageItemID,
        category: ManageStorageCategory,
        protection: ManageStorageProtection,
        source: ManageStorageSource,
        countsTowardTotal: Bool = true,
        byteCount: Int64 = 0
    ) {
        self.id = id
        self.category = category
        self.protection = protection
        self.source = source
        self.countsTowardTotal = countsTowardTotal
        self.byteCount = byteCount
    }

    var title: String { id.title }
    var explanation: String { id.explanation }
    var isDeletable: Bool { protection.isDeletable }

    /// Only a deletable row that currently holds something can free space.
    var isCleanable: Bool { isDeletable && byteCount > 0 }

    var formattedSize: String {
        ManageStorageItem.formatted(byteCount: byteCount)
    }

    static func formatted(byteCount: Int64) -> String {
        byteCount.formatted(.byteCount(style: .file))
    }

    func matches(searchTerm: String) -> Bool {
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return [title, explanation, category.title].contains { $0.localizedStandardContains(term) }
    }
}
