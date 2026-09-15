@testable import HomeAssistant

import Shared
import Testing
import WidgetKit

/// The parts of the areas widget's paging that aren't drawn: where the page is remembered, and what
/// the arrows do at the two ends of a home.
@Suite(.serialized)
struct WidgetAreasPagingTests {
    private static let serverId = "paging-tests-server"

    private func clearStoredPage(family: WidgetFamily) {
        UserDefaults(suiteName: AppConstants.AppGroupID)?
            .removeObject(forKey: "widget-areas-page-\(Self.serverId)-\(family.rawValue)")
    }

    @Test func aWidgetStartsOnTheFirstPage() {
        clearStoredPage(family: .systemLarge)
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemLarge) == 0)
    }

    /// Each family remembers its own page, so a small and a large widget on the same server don't
    /// drag each other around.
    @Test func pagesAreRememberedPerFamily() {
        clearStoredPage(family: .systemSmall)
        clearStoredPage(family: .systemLarge)
        WidgetAreasPageStore.setPage(2, serverId: Self.serverId, family: .systemLarge)
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemLarge) == 2)
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemSmall) == 0)
        clearStoredPage(family: .systemLarge)
    }

    /// A stored page that has outlived the areas under it lands on the last page there is, and a
    /// server with no areas at all on the first.
    @Test func storedPageIsClampedToWhatIsLeft() {
        #expect(WidgetAreasPageStore.clamp(7, pageCount: 3) == 2)
        #expect(WidgetAreasPageStore.clamp(-1, pageCount: 3) == 0)
        #expect(WidgetAreasPageStore.clamp(2, pageCount: 0) == 0)
    }

    @available(iOS 17, *)
    @Test func theArrowsStepThroughTheHomeAndStopAtItsEnds() async throws {
        clearStoredPage(family: .systemMedium)
        let intent = WidgetAreasPageAppIntent()
        intent.serverId = Self.serverId
        intent.familyRawValue = WidgetFamily.systemMedium.rawValue
        intent.pageCount = 3

        intent.step = 1
        _ = try await intent.perform()
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemMedium) == 1)

        _ = try await intent.perform()
        _ = try await intent.perform()
        // The last page is as far as the forward arrow goes.
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemMedium) == 2)

        intent.step = -1
        _ = try await intent.perform()
        _ = try await intent.perform()
        _ = try await intent.perform()
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemMedium) == 0)
        clearStoredPage(family: .systemMedium)
    }

    /// An arrow that reaches the intent without the widget's own details changes nothing rather than
    /// paging some other widget.
    @available(iOS 17, *)
    @Test func anIncompleteIntentDoesNothing() async throws {
        clearStoredPage(family: .systemMedium)
        WidgetAreasPageStore.setPage(1, serverId: Self.serverId, family: .systemMedium)
        let intent = WidgetAreasPageAppIntent()
        intent.step = 1
        _ = try await intent.perform()
        #expect(WidgetAreasPageStore.page(serverId: Self.serverId, family: .systemMedium) == 1)
        clearStoredPage(family: .systemMedium)
    }
}
