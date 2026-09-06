import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// Covers what `ManageStorageMeasurer()` and `ManageStorageCleaner()` reach for when nothing is
/// injected. Every other test supplies its own doubles, so without these the wiring that the app
/// actually runs — `URLCache.shared`, `Current.database()`, `Current.websiteDataStoreHandler` —
/// would never be exercised.
struct ManageStorageProductionDefaultsTests {
    private func item(source: ManageStorageSource) -> ManageStorageItem {
        ManageStorageItem(id: .networkResponseCache, category: .caches, protection: .deletable, source: source)
    }

    // `URLCache.shared` is process-wide: the rest of the suite shares it, and nothing promises that
    // clearing it reports zero straight away. So this asserts the relationship between measuring and
    // clearing rather than either exact number.
    @Test func theDefaultsReadAndClearUrlCache() async throws {
        let measurer = ManageStorageMeasurer()
        let before = await measurer.byteCount(of: item(source: .networkResponseCache))

        try await ManageStorageCleaner().clean(item(source: .networkResponseCache))
        let after = await measurer.byteCount(of: item(source: .networkResponseCache))

        #expect(after <= before)
    }

    @Test func theDefaultMeasurerReadsTheAppDatabase() async {
        // A table that is not there exercises the database closure without depending on any rows
        // the rest of the suite happens to have written.
        let measured = await ManageStorageMeasurer().byteCount(of: item(source: .databaseTables(["not_a_table"])))

        #expect(measured == 0)
    }

    @Test func theDefaultCleanerClearsWebContentThroughTheWebsiteDataStore() async throws {
        let original = Current.websiteDataStoreHandler
        defer { Current.websiteDataStoreHandler = original }
        let handler = ImmediateWebsiteDataStoreHandler()
        Current.websiteDataStoreHandler = handler

        try await ManageStorageCleaner().clean(item(source: .webKit(urls: [], dataTypes: ["cookies"])))

        #expect(handler.lastDataTypes == ["cookies"])
    }

    @Test func theDefaultCleanerSkipsTablesTheDatabaseDoesNotHave() async throws {
        try await ManageStorageCleaner().clean(item(source: .databaseTables(["not_a_table"])))
    }
}
