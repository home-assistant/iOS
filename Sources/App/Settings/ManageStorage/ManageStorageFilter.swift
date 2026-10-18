import Foundation

/// What the user narrowed the "Manage Storage" list down to.
struct ManageStorageFilter: Equatable {
    var searchTerm: String = ""
    var category: ManageStorageCategory?
    /// Hides everything the screen would refuse to delete anyway.
    var onlyDeletable: Bool = false

    var isActive: Bool {
        !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || category != nil
            || onlyDeletable
    }

    func apply(to items: [ManageStorageItem]) -> [ManageStorageItem] {
        items.filter { item in
            guard item.matches(searchTerm: searchTerm) else { return false }
            if let category, item.category != category { return false }
            if onlyDeletable, !item.isDeletable { return false }
            return true
        }
    }
}
