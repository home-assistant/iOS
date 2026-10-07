import Foundation
@testable import HomeAssistant
import Testing

struct ManageStorageFilterTests {
    private let items = ManageStorageInventory.items(
        paths: .rooted(at: URL(fileURLWithPath: "/tmp/manage-storage-filter")),
        isCatalyst: false,
        hasCompletedLegacyStoreMigration: true
    )

    @Test func anUntouchedFilterIsInactiveAndKeepsEverything() {
        let filter = ManageStorageFilter()

        #expect(!filter.isActive)
        #expect(filter.apply(to: items).count == items.count)
    }

    @Test func whitespaceOnlySearchDoesNotCountAsFiltering() {
        var filter = ManageStorageFilter()
        filter.searchTerm = "   "

        #expect(!filter.isActive)
        #expect(filter.apply(to: items).count == items.count)
    }

    @Test func eachCriterionOnItsOwnMarksTheFilterActive() {
        var searching = ManageStorageFilter()
        searching.searchTerm = "log"
        var categorised = ManageStorageFilter()
        categorised.category = .caches
        var deletableOnly = ManageStorageFilter()
        deletableOnly.onlyDeletable = true

        #expect(searching.isActive)
        #expect(categorised.isActive)
        #expect(deletableOnly.isActive)
    }

    @Test func filteringByCategoryKeepsOnlyThatCategory() {
        var filter = ManageStorageFilter()
        filter.category = .webContent

        let filtered = filter.apply(to: items)

        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { $0.category == .webContent })
    }

    @Test func filteringToRemovableRowsDropsProtectedOnes() {
        var filter = ManageStorageFilter()
        filter.onlyDeletable = true

        let filtered = filter.apply(to: items)
        // Hoisted out of `#expect`: the macro cannot prove a key path handed to a `rethrows`
        // method is non-throwing, and SwiftFormat rewrites the equivalent closure to a key path.
        let allDeletable = filtered.allSatisfy(\.isDeletable)

        #expect(allDeletable)
        #expect(filtered.count < items.count)
    }

    @Test func criteriaCombine() {
        var filter = ManageStorageFilter()
        filter.category = .appData
        filter.onlyDeletable = true
        filter.searchTerm = ManageStorageItemID.legacyRealmStore.title

        let filtered = filter.apply(to: items)

        #expect(filtered.map(\.id) == [.legacyRealmStore])
    }

    @Test func searchThatMatchesNothingReturnsNothing() {
        var filter = ManageStorageFilter()
        filter.searchTerm = "zzzzz-no-such-row"

        #expect(filter.apply(to: items).isEmpty)
    }
}
